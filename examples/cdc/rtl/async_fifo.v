// =============================================================================
// SpyGlass CDC Example: Asynchronous FIFO (Complete CDC Solution)
// =============================================================================
//
// A properly designed asynchronous FIFO is the standard solution for
// transferring multi-bit data between two asynchronous clock domains.
//
// Key CDC techniques demonstrated:
//   1. Gray-coded write and read pointers (only 1 bit changes per increment)
//   2. Two-flop synchronizers for crossing pointers between domains
//   3. Full flag generated in the write-clock domain
//   4. Empty flag generated in the read-clock domain
//   5. Dual-port RAM accessed by each clock domain independently
//
// Run with: current_goal cdc/cdc_verify
// =============================================================================

module async_fifo #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 4   // FIFO depth = 2^ADDR_WIDTH = 16
)(
    // Write interface (clk_wr domain)
    input                    clk_wr,
    input                    rst_wr_n,
    input                    wr_en,
    input  [DATA_WIDTH-1:0]  wr_data,
    output                   full,

    // Read interface (clk_rd domain)
    input                    clk_rd,
    input                    rst_rd_n,
    input                    rd_en,
    output [DATA_WIDTH-1:0]  rd_data,
    output                   empty
);

    // =========================================================================
    // Dual-Port RAM
    // =========================================================================
    reg [DATA_WIDTH-1:0] mem [0:(1<<ADDR_WIDTH)-1];

    wire [ADDR_WIDTH-1:0] wr_addr, rd_addr;

    always @(posedge clk_wr) begin
        if (wr_en && !full)
            mem[wr_addr] <= wr_data;
    end

    assign rd_data = mem[rd_addr];

    // =========================================================================
    // Write Pointer (Binary & Gray) — clk_wr domain
    // =========================================================================
    reg [ADDR_WIDTH:0] wr_ptr_bin;
    wire [ADDR_WIDTH:0] wr_ptr_gray;

    always @(posedge clk_wr or negedge rst_wr_n) begin
        if (!rst_wr_n)
            wr_ptr_bin <= {(ADDR_WIDTH+1){1'b0}};
        else if (wr_en && !full)
            wr_ptr_bin <= wr_ptr_bin + 1'b1;
    end

    assign wr_ptr_gray = wr_ptr_bin ^ (wr_ptr_bin >> 1);
    assign wr_addr     = wr_ptr_bin[ADDR_WIDTH-1:0];

    // =========================================================================
    // Read Pointer (Binary & Gray) — clk_rd domain
    // =========================================================================
    reg [ADDR_WIDTH:0] rd_ptr_bin;
    wire [ADDR_WIDTH:0] rd_ptr_gray;

    always @(posedge clk_rd or negedge rst_rd_n) begin
        if (!rst_rd_n)
            rd_ptr_bin <= {(ADDR_WIDTH+1){1'b0}};
        else if (rd_en && !empty)
            rd_ptr_bin <= rd_ptr_bin + 1'b1;
    end

    assign rd_ptr_gray = rd_ptr_bin ^ (rd_ptr_bin >> 1);
    assign rd_addr     = rd_ptr_bin[ADDR_WIDTH-1:0];

    // =========================================================================
    // Synchronize Write Pointer into Read Domain (for empty flag)
    // =========================================================================
    reg [ADDR_WIDTH:0] wr_ptr_gray_rd1, wr_ptr_gray_rd2;

    always @(posedge clk_rd or negedge rst_rd_n) begin
        if (!rst_rd_n) begin
            wr_ptr_gray_rd1 <= {(ADDR_WIDTH+1){1'b0}};
            wr_ptr_gray_rd2 <= {(ADDR_WIDTH+1){1'b0}};
        end else begin
            wr_ptr_gray_rd1 <= wr_ptr_gray;      // First sync stage
            wr_ptr_gray_rd2 <= wr_ptr_gray_rd1;   // Second sync stage
        end
    end

    // =========================================================================
    // Synchronize Read Pointer into Write Domain (for full flag)
    // =========================================================================
    reg [ADDR_WIDTH:0] rd_ptr_gray_wr1, rd_ptr_gray_wr2;

    always @(posedge clk_wr or negedge rst_wr_n) begin
        if (!rst_wr_n) begin
            rd_ptr_gray_wr1 <= {(ADDR_WIDTH+1){1'b0}};
            rd_ptr_gray_wr2 <= {(ADDR_WIDTH+1){1'b0}};
        end else begin
            rd_ptr_gray_wr1 <= rd_ptr_gray;        // First sync stage
            rd_ptr_gray_wr2 <= rd_ptr_gray_wr1;     // Second sync stage
        end
    end

    // =========================================================================
    // Full & Empty Flag Generation
    // =========================================================================

    // FIFO is empty when the synchronized write pointer equals the read pointer
    // (both in Gray code, compared in the read domain)
    assign empty = (rd_ptr_gray == wr_ptr_gray_rd2);

    // FIFO is full when the write pointer's Gray code matches the read pointer's
    // Gray code with the top two bits inverted (both compared in write domain)
    assign full = (wr_ptr_gray == {~rd_ptr_gray_wr2[ADDR_WIDTH:ADDR_WIDTH-1],
                                     rd_ptr_gray_wr2[ADDR_WIDTH-2:0]});

endmodule
