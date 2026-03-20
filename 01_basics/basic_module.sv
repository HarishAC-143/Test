// Parameterized adder with carry-out.
// Demonstrates: module ports, parameters, continuous assignment.

module basic_adder #(
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
