// =============================================================================
// async_fifo -- Asynchronous FIFO with Gray-Coded Pointers
//
// The most robust mechanism for streaming data between two clock domains.
// Write and read pointers are maintained in their respective domains and
// synchronized to the opposite domain using Gray encoding + 2-FF sync.
//
// Parameters:
//   DATA_WIDTH -- width of each FIFO entry (default 8)
//   ADDR_WIDTH -- log2 of FIFO depth (default 4 -> 16 entries)
//
// Key properties:
//   - Gray-coded pointers ensure at most 1 bit changes per clock cycle,
//     making 2-FF synchronization safe.
//   - Full/empty flags are conservative (may indicate full/empty slightly
//     early, but never late).
// =============================================================================

module async_fifo #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 4
) (
    // Write interface (clk_wr domain)
    input  wire                  clk_wr,
    input  wire                  rst_wr_n,
    input  wire [DATA_WIDTH-1:0] wr_data,
    input  wire                  wr_en,
    output wire                  full,

    // Read interface (clk_rd domain)
    input  wire                  clk_rd,
    input  wire                  rst_rd_n,
    output wire [DATA_WIDTH-1:0] rd_data,
    input  wire                  rd_en,
    output wire                  empty
);

    localparam DEPTH = 1 << ADDR_WIDTH;

    // -----------------------------------------------------------------
    // FIFO memory
    // -----------------------------------------------------------------
    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    // -----------------------------------------------------------------
    // Write pointer (binary and Gray)
    // -----------------------------------------------------------------
    reg [ADDR_WIDTH:0] wr_ptr_bin;
    wire [ADDR_WIDTH:0] wr_ptr_gray = wr_ptr_bin ^ (wr_ptr_bin >> 1);

    always @(posedge clk_wr or negedge rst_wr_n) begin
        if (!rst_wr_n)
            wr_ptr_bin <= 0;
        else if (wr_en && !full)
            wr_ptr_bin <= wr_ptr_bin + 1;
    end

    always @(posedge clk_wr) begin
        if (wr_en && !full)
            mem[wr_ptr_bin[ADDR_WIDTH-1:0]] <= wr_data;
    end

    // -----------------------------------------------------------------
    // Read pointer (binary and Gray)
    // -----------------------------------------------------------------
    reg [ADDR_WIDTH:0] rd_ptr_bin;
    wire [ADDR_WIDTH:0] rd_ptr_gray = rd_ptr_bin ^ (rd_ptr_bin >> 1);

    always @(posedge clk_rd or negedge rst_rd_n) begin
        if (!rst_rd_n)
            rd_ptr_bin <= 0;
        else if (rd_en && !empty)
            rd_ptr_bin <= rd_ptr_bin + 1;
    end

    assign rd_data = mem[rd_ptr_bin[ADDR_WIDTH-1:0]];

    // -----------------------------------------------------------------
    // Synchronize write pointer (Gray) into read domain for empty flag
    // -----------------------------------------------------------------
    wire [ADDR_WIDTH:0] wr_ptr_gray_rd;

    sync_2ff #(.WIDTH(ADDR_WIDTH+1)) u_sync_wr2rd (
        .clk   (clk_rd),
        .rst_n (rst_rd_n),
        .d     (wr_ptr_gray),
        .q     (wr_ptr_gray_rd)
    );

    assign empty = (rd_ptr_gray == wr_ptr_gray_rd);

    // -----------------------------------------------------------------
    // Synchronize read pointer (Gray) into write domain for full flag
    // -----------------------------------------------------------------
    wire [ADDR_WIDTH:0] rd_ptr_gray_wr;

    sync_2ff #(.WIDTH(ADDR_WIDTH+1)) u_sync_rd2wr (
        .clk   (clk_wr),
        .rst_n (rst_wr_n),
        .d     (rd_ptr_gray),
        .q     (rd_ptr_gray_wr)
    );

    assign full = (wr_ptr_gray == {~rd_ptr_gray_wr[ADDR_WIDTH:ADDR_WIDTH-1],
                                     rd_ptr_gray_wr[ADDR_WIDTH-2:0]});

endmodule
