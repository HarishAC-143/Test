// =============================================================================
// Practical Example: Asynchronous FIFO
// =============================================================================
// A complete async FIFO implementation demonstrating proper CDC techniques:
//   - Dual-port memory with independent read/write clocks
//   - Gray-coded pointers for safe cross-domain comparison
//   - 2-FF synchronizers for pointer crossing
//   - Full/empty flag generation using synchronized pointers
//
// This is the gold-standard approach for streaming data between clock domains.
// SpyGlass CDC should report zero violations on this module.
//
// Parameters:
//   DATA_WIDTH — Width of data bus (default: 8)
//   ADDR_WIDTH — Address width; FIFO depth = 2^ADDR_WIDTH (default: 4 → 16 deep)
// =============================================================================

module async_fifo #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 4
) (
    // Write port (Domain A)
    input  wire                  wr_clk,
    input  wire                  wr_rst_n,
    input  wire                  wr_en,
    input  wire [DATA_WIDTH-1:0] wr_data,
    output wire                  full,

    // Read port (Domain B)
    input  wire                  rd_clk,
    input  wire                  rd_rst_n,
    input  wire                  rd_en,
    output wire [DATA_WIDTH-1:0] rd_data,
    output wire                  empty
);

    localparam FIFO_DEPTH = 1 << ADDR_WIDTH;

    // =========================================================================
    // Dual-Port Memory
    // =========================================================================
    reg [DATA_WIDTH-1:0] mem [0:FIFO_DEPTH-1];

    // =========================================================================
    // Write Pointer — Binary and Gray (wr_clk domain)
    // =========================================================================
    reg [ADDR_WIDTH:0] wr_ptr_bin;      // Extra bit for full/empty detection
    reg [ADDR_WIDTH:0] wr_ptr_gray;

    wire [ADDR_WIDTH:0] wr_ptr_bin_next  = wr_ptr_bin + (wr_en & ~full);
    wire [ADDR_WIDTH:0] wr_ptr_gray_next = wr_ptr_bin_next ^ (wr_ptr_bin_next >> 1);

    always @(posedge wr_clk or negedge wr_rst_n) begin
        if (!wr_rst_n) begin
            wr_ptr_bin  <= {(ADDR_WIDTH+1){1'b0}};
            wr_ptr_gray <= {(ADDR_WIDTH+1){1'b0}};
        end else begin
            wr_ptr_bin  <= wr_ptr_bin_next;
            wr_ptr_gray <= wr_ptr_gray_next;
        end
    end

    // Write data to memory
    always @(posedge wr_clk) begin
        if (wr_en && !full)
            mem[wr_ptr_bin[ADDR_WIDTH-1:0]] <= wr_data;
    end

    // =========================================================================
    // Read Pointer — Binary and Gray (rd_clk domain)
    // =========================================================================
    reg [ADDR_WIDTH:0] rd_ptr_bin;
    reg [ADDR_WIDTH:0] rd_ptr_gray;

    wire [ADDR_WIDTH:0] rd_ptr_bin_next  = rd_ptr_bin + (rd_en & ~empty);
    wire [ADDR_WIDTH:0] rd_ptr_gray_next = rd_ptr_bin_next ^ (rd_ptr_bin_next >> 1);

    always @(posedge rd_clk or negedge rd_rst_n) begin
        if (!rd_rst_n) begin
            rd_ptr_bin  <= {(ADDR_WIDTH+1){1'b0}};
            rd_ptr_gray <= {(ADDR_WIDTH+1){1'b0}};
        end else begin
            rd_ptr_bin  <= rd_ptr_bin_next;
            rd_ptr_gray <= rd_ptr_gray_next;
        end
    end

    // Read data from memory
    assign rd_data = mem[rd_ptr_bin[ADDR_WIDTH-1:0]];

    // =========================================================================
    // Pointer Synchronization (Gray-coded, 2-FF)
    // =========================================================================

    // Synchronize write pointer (Gray) into read clock domain
    // Used to generate 'empty' flag
    reg [ADDR_WIDTH:0] wr_ptr_gray_rd_sync1, wr_ptr_gray_rd_sync2;

    always @(posedge rd_clk or negedge rd_rst_n) begin
        if (!rd_rst_n) begin
            wr_ptr_gray_rd_sync1 <= {(ADDR_WIDTH+1){1'b0}};
            wr_ptr_gray_rd_sync2 <= {(ADDR_WIDTH+1){1'b0}};
        end else begin
            wr_ptr_gray_rd_sync1 <= wr_ptr_gray;
            wr_ptr_gray_rd_sync2 <= wr_ptr_gray_rd_sync1;
        end
    end

    // Synchronize read pointer (Gray) into write clock domain
    // Used to generate 'full' flag
    reg [ADDR_WIDTH:0] rd_ptr_gray_wr_sync1, rd_ptr_gray_wr_sync2;

    always @(posedge wr_clk or negedge wr_rst_n) begin
        if (!wr_rst_n) begin
            rd_ptr_gray_wr_sync1 <= {(ADDR_WIDTH+1){1'b0}};
            rd_ptr_gray_wr_sync2 <= {(ADDR_WIDTH+1){1'b0}};
        end else begin
            rd_ptr_gray_wr_sync1 <= rd_ptr_gray;
            rd_ptr_gray_wr_sync2 <= rd_ptr_gray_wr_sync1;
        end
    end

    // =========================================================================
    // Full and Empty Flags
    // =========================================================================
    //
    // In Gray code:
    //   EMPTY: write pointer (synced to rd domain) == read pointer
    //          → FIFO has been read up to where writes have reached
    //
    //   FULL:  The write pointer has wrapped around and caught up to
    //          the read pointer. In Gray code, this is detected when
    //          the top 2 bits are inverted and the remaining bits match.
    //
    // Gray code full condition (for N+1 bit pointers):
    //   wr_gray[N:N-1] == ~rd_gray[N:N-1]  AND  wr_gray[N-2:0] == rd_gray[N-2:0]

    assign empty = (rd_ptr_gray == wr_ptr_gray_rd_sync2);

    assign full  = (wr_ptr_gray_next == {~rd_ptr_gray_wr_sync2[ADDR_WIDTH:ADDR_WIDTH-1],
                                          rd_ptr_gray_wr_sync2[ADDR_WIDTH-2:0]});

endmodule
