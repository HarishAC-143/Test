// ============================================================================
// Ripple-Carry Adder using Generate-For
// ============================================================================
// Demonstrates `generate for` to instantiate a parameterized number of
// full adders. Each generate iteration creates a named scope (gen_fa[i])
// that is visible in the hierarchy for debugging.
// ============================================================================

module full_adder (
    input  logic a,
    input  logic b,
    input  logic cin,
    output logic sum,
    output logic cout
);
    assign sum  = a ^ b ^ cin;
    assign cout = (a & b) | (a & cin) | (b & cin);
endmodule


module ripple_carry_adder #(
    parameter int WIDTH = 8
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
            full_adder u_fa (
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
