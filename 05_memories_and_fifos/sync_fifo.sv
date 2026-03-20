// Synchronous FIFO with parameterized depth and width.
// Uses a circular buffer with binary pointers.
// Depth must be a power of two.

module sync_fifo #(
    parameter int DATA_WIDTH = 8,
    parameter int DEPTH      = 16    // must be power of 2
)(
    input  logic                  clk,
    input  logic                  rst_n,

    // Write interface
    input  logic                  wr_en,
    input  logic [DATA_WIDTH-1:0] wr_data,

    // Read interface
    input  logic                  rd_en,
    output logic [DATA_WIDTH-1:0] rd_data,

    // Status
    output logic                  full,
    output logic                  empty,
    output logic [$clog2(DEPTH):0] count
);

    localparam int PTR_WIDTH = $clog2(DEPTH);

    logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    logic [PTR_WIDTH:0]    wr_ptr, rd_ptr;  // extra bit for full/empty disambiguation

    // Write logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= '0;
        end else if (wr_en && !full) begin
            mem[wr_ptr[PTR_WIDTH-1:0]] <= wr_data;
            wr_ptr <= wr_ptr + 1'b1;
        end
    end

    // Read logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_ptr <= '0;
        end else if (rd_en && !empty) begin
            rd_ptr <= rd_ptr + 1'b1;
        end
    end

    assign rd_data = mem[rd_ptr[PTR_WIDTH-1:0]];

    // Status flags
    assign empty = (wr_ptr == rd_ptr);
    assign full  = (wr_ptr[PTR_WIDTH] != rd_ptr[PTR_WIDTH]) &&
                   (wr_ptr[PTR_WIDTH-1:0] == rd_ptr[PTR_WIDTH-1:0]);
    assign count = wr_ptr - rd_ptr;

endmodule
