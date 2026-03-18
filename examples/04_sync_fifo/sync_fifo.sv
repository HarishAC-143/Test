// Synchronous FIFO
// Single-clock-domain FIFO with configurable depth, data width,
// and almost-full/almost-empty thresholds.

module sync_fifo #(
    parameter int DATA_WIDTH    = 8,
    parameter int DEPTH         = 16,
    parameter int ALMOST_FULL   = DEPTH - 2,
    parameter int ALMOST_EMPTY  = 2,
    localparam int ADDR_WIDTH   = $clog2(DEPTH)
) (
    input  logic                  clk,
    input  logic                  rst_n,

    // Write interface
    input  logic                  wr_en,
    input  logic [DATA_WIDTH-1:0] wr_data,

    // Read interface
    input  logic                  rd_en,
    output logic [DATA_WIDTH-1:0] rd_data,

    // Status flags
    output logic                  full,
    output logic                  empty,
    output logic                  almost_full,
    output logic                  almost_empty,
    output logic [ADDR_WIDTH:0]   fill_level
);

    // Memory array
    logic [DATA_WIDTH-1:0] mem [DEPTH];

    // Pointers with extra MSB for full/empty disambiguation
    logic [ADDR_WIDTH:0] wr_ptr;
    logic [ADDR_WIDTH:0] rd_ptr;

    // Internal write/read enable (gated by full/empty)
    logic wr_valid;
    logic rd_valid;

    assign wr_valid = wr_en && !full;
    assign rd_valid = rd_en && !empty;

    // Write pointer
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            wr_ptr <= '0;
        else if (wr_valid)
            wr_ptr <= wr_ptr + 1;
    end

    // Read pointer
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            rd_ptr <= '0;
        else if (rd_valid)
            rd_ptr <= rd_ptr + 1;
    end

    // Memory write
    always_ff @(posedge clk) begin
        if (wr_valid)
            mem[wr_ptr[ADDR_WIDTH-1:0]] <= wr_data;
    end

    // Memory read (registered output for timing)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            rd_data <= '0;
        else if (rd_valid)
            rd_data <= mem[rd_ptr[ADDR_WIDTH-1:0]];
    end

    // Status flags
    assign fill_level   = wr_ptr - rd_ptr;
    assign full         = (fill_level == DEPTH);
    assign empty        = (fill_level == 0);
    assign almost_full  = (fill_level >= ALMOST_FULL);
    assign almost_empty = (fill_level <= ALMOST_EMPTY) && !empty;

endmodule
