// ============================================================================
// Parameterized Adder
// ============================================================================
// A simple N-bit ripple-carry adder demonstrating module declaration,
// parameterization, and continuous assignment in SystemVerilog.
// ============================================================================

module adder #(
    parameter int WIDTH = 8
)(
    input  logic [WIDTH-1:0] a,
    input  logic [WIDTH-1:0] b,
    input  logic             cin,
    output logic [WIDTH-1:0] sum,
    output logic             cout
);

    assign {cout, sum} = a + b + cin;

endmodule
