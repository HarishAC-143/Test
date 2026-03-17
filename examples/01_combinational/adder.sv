// Ripple Carry Adder built from full adders

module full_adder (
    input  logic a,
    input  logic b,
    input  logic cin,
    output logic sum,
    output logic cout
);

    assign sum  = a ^ b ^ cin;
    assign cout = (a & b) | (cin & (a ^ b));

endmodule


module ripple_carry_adder #(
    parameter WIDTH = 8
)(
    input  logic [WIDTH-1:0] a,
    input  logic [WIDTH-1:0] b,
    input  logic             cin,
    output logic [WIDTH-1:0] sum,
    output logic             cout
);

    logic [WIDTH:0] carry;

    assign carry[0] = cin;

    genvar i;
    generate
        for (i = 0; i < WIDTH; i++) begin : gen_fa
            full_adder fa (
                .a    (a[i]),
                .b    (b[i]),
                .cin  (carry[i]),
                .sum  (sum[i]),
                .cout (carry[i+1])
            );
        end
    endgenerate

    assign cout = carry[WIDTH];

endmodule


// Carry Look-Ahead Adder for faster addition
module carry_lookahead_adder #(
    parameter WIDTH = 4
)(
    input  logic [WIDTH-1:0] a,
    input  logic [WIDTH-1:0] b,
    input  logic             cin,
    output logic [WIDTH-1:0] sum,
    output logic             cout
);

    logic [WIDTH-1:0] generate_g;
    logic [WIDTH-1:0] propagate_p;
    logic [WIDTH:0]   carry;

    assign carry[0] = cin;

    genvar i;
    generate
        for (i = 0; i < WIDTH; i++) begin : gen_gp
            assign generate_g[i]  = a[i] & b[i];
            assign propagate_p[i] = a[i] ^ b[i];
            assign carry[i+1]     = generate_g[i] | (propagate_p[i] & carry[i]);
            assign sum[i]         = propagate_p[i] ^ carry[i];
        end
    endgenerate

    assign cout = carry[WIDTH];

endmodule
