// =============================================================================
// Asynchronous FIFO with Gray Code Pointer Synchronization
// =============================================================================
// A complete, CDC-clean asynchronous FIFO implementation.
// Uses Gray code encoding for pointer synchronization across clock domains.
//
// Key CDC design features:
// - Write pointer synchronized to read clock domain (for empty detection)
// - Read pointer synchronized to write clock domain (for full detection)
// - Gray code ensures only 1 bit changes per increment (safe for 2FF sync)
// - Dual-port RAM accessed by independent clocks
// =============================================================================

module async_fifo #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 4    // FIFO depth = 2^ADDR_WIDTH = 16 entries
) (
    // Write interface (write clock domain)
    input  wire                  wr_clk,
    input  wire                  wr_rst_n,
    input  wire                  wr_en,
    input  wire [DATA_WIDTH-1:0] wr_data,
    output wire                  wr_full,

    // Read interface (read clock domain)
    input  wire                  rd_clk,
    input  wire                  rd_rst_n,
    input  wire                  rd_en,
    output wire [DATA_WIDTH-1:0] rd_data,
    output wire                  rd_empty
);

    // Pointer width includes an extra MSB for full/empty distinction
    localparam PTR_WIDTH = ADDR_WIDTH + 1;

    // =========================================================================
    // Dual-Port RAM
    // =========================================================================
    reg [DATA_WIDTH-1:0] mem [0:(1<<ADDR_WIDTH)-1];

    // Write port
    always @(posedge wr_clk) begin
        if (wr_en && !wr_full)
            mem[wr_ptr_bin[ADDR_WIDTH-1:0]] <= wr_data;
    end

    // Read port
    assign rd_data = mem[rd_ptr_bin[ADDR_WIDTH-1:0]];

    // =========================================================================
    // Write Pointer Logic (write clock domain)
    // =========================================================================
    reg [PTR_WIDTH-1:0] wr_ptr_bin;
    reg [PTR_WIDTH-1:0] wr_ptr_gray;

    wire [PTR_WIDTH-1:0] wr_ptr_bin_next  = wr_ptr_bin + (wr_en & ~wr_full);
    wire [PTR_WIDTH-1:0] wr_ptr_gray_next = wr_ptr_bin_next ^ (wr_ptr_bin_next >> 1);

    always @(posedge wr_clk or negedge wr_rst_n) begin
        if (!wr_rst_n) begin
            wr_ptr_bin  <= {PTR_WIDTH{1'b0}};
            wr_ptr_gray <= {PTR_WIDTH{1'b0}};
        end else begin
            wr_ptr_bin  <= wr_ptr_bin_next;
            wr_ptr_gray <= wr_ptr_gray_next;
        end
    end

    // =========================================================================
    // Read Pointer Logic (read clock domain)
    // =========================================================================
    reg [PTR_WIDTH-1:0] rd_ptr_bin;
    reg [PTR_WIDTH-1:0] rd_ptr_gray;

    wire [PTR_WIDTH-1:0] rd_ptr_bin_next  = rd_ptr_bin + (rd_en & ~rd_empty);
    wire [PTR_WIDTH-1:0] rd_ptr_gray_next = rd_ptr_bin_next ^ (rd_ptr_bin_next >> 1);

    always @(posedge rd_clk or negedge rd_rst_n) begin
        if (!rd_rst_n) begin
            rd_ptr_bin  <= {PTR_WIDTH{1'b0}};
            rd_ptr_gray <= {PTR_WIDTH{1'b0}};
        end else begin
            rd_ptr_bin  <= rd_ptr_bin_next;
            rd_ptr_gray <= rd_ptr_gray_next;
        end
    end

    // =========================================================================
    // Pointer Synchronization (CDC)
    // =========================================================================

    // Synchronize write pointer (Gray) to read clock domain
    reg [PTR_WIDTH-1:0] wr_ptr_gray_rd_sync1;
    reg [PTR_WIDTH-1:0] wr_ptr_gray_rd_sync2;

    always @(posedge rd_clk or negedge rd_rst_n) begin
        if (!rd_rst_n) begin
            wr_ptr_gray_rd_sync1 <= {PTR_WIDTH{1'b0}};
            wr_ptr_gray_rd_sync2 <= {PTR_WIDTH{1'b0}};
        end else begin
            wr_ptr_gray_rd_sync1 <= wr_ptr_gray;
            wr_ptr_gray_rd_sync2 <= wr_ptr_gray_rd_sync1;
        end
    end

    // Synchronize read pointer (Gray) to write clock domain
    reg [PTR_WIDTH-1:0] rd_ptr_gray_wr_sync1;
    reg [PTR_WIDTH-1:0] rd_ptr_gray_wr_sync2;

    always @(posedge wr_clk or negedge wr_rst_n) begin
        if (!wr_rst_n) begin
            rd_ptr_gray_wr_sync1 <= {PTR_WIDTH{1'b0}};
            rd_ptr_gray_wr_sync2 <= {PTR_WIDTH{1'b0}};
        end else begin
            rd_ptr_gray_wr_sync1 <= rd_ptr_gray;
            rd_ptr_gray_wr_sync2 <= rd_ptr_gray_wr_sync1;
        end
    end

    // =========================================================================
    // Full and Empty Generation
    // =========================================================================

    // FIFO is empty when write pointer (synced to rd_clk) equals read pointer
    assign rd_empty = (wr_ptr_gray_rd_sync2 == rd_ptr_gray);

    // FIFO is full when:
    //   - MSBs of write and read Gray pointers differ (wrap-around)
    //   - Second MSBs differ
    //   - Remaining bits are equal
    assign wr_full = (wr_ptr_gray[PTR_WIDTH-1]   != rd_ptr_gray_wr_sync2[PTR_WIDTH-1]) &&
                     (wr_ptr_gray[PTR_WIDTH-2]   != rd_ptr_gray_wr_sync2[PTR_WIDTH-2]) &&
                     (wr_ptr_gray[PTR_WIDTH-3:0] == rd_ptr_gray_wr_sync2[PTR_WIDTH-3:0]);

endmodule
