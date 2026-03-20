// Basic SystemVerilog module: Simple buffer (wire connection)
// Demonstrates module declaration, port definitions, and continuous assignment

module hello_world (
    input  logic       clk,
    input  logic       rst_n,
    input  logic [7:0] data_in,
    output logic [7:0] data_out
);

    assign data_out = data_in;

endmodule
