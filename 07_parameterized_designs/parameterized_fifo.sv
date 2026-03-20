// Type-parameterized FIFO.
// The data type itself is a parameter, so this FIFO can store structs,
// enums, or any packed type — not just plain logic vectors.

module parameterized_fifo #(
    parameter type DATA_T = logic [7:0],
    parameter int  DEPTH  = 16
)(
    input  logic  clk,
    input  logic  rst_n,
    input  logic  push,
    input  DATA_T push_data,
    input  logic  pop,
    output DATA_T pop_data,
    output logic  full,
    output logic  empty,
    output logic [$clog2(DEPTH):0] count
);

    localparam int PTR_W = $clog2(DEPTH);

    DATA_T mem [0:DEPTH-1];
    logic [PTR_W:0] wr_ptr, rd_ptr;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= '0;
        end else if (push && !full) begin
            mem[wr_ptr[PTR_W-1:0]] <= push_data;
            wr_ptr <= wr_ptr + 1'b1;
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            rd_ptr <= '0;
        else if (pop && !empty)
            rd_ptr <= rd_ptr + 1'b1;
    end

    assign pop_data = mem[rd_ptr[PTR_W-1:0]];
    assign full     = (wr_ptr[PTR_W] != rd_ptr[PTR_W]) &&
                      (wr_ptr[PTR_W-1:0] == rd_ptr[PTR_W-1:0]);
    assign empty    = (wr_ptr == rd_ptr);
    assign count    = wr_ptr - rd_ptr;

endmodule
