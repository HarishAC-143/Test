// =============================================================================
// 32-Bit Carry Lookahead Adder (CLA)
// Demonstrates generate/propagate logic for fast addition.
// Built as a hierarchical 4-bit CLA extended to 32 bits.
// =============================================================================

module cla_4bit (
    input  logic [3:0] a,
    input  logic [3:0] b,
    input  logic       cin,
    output logic [3:0] sum,
    output logic       cout,
    output logic       pg,    // Group propagate
    output logic       gg     // Group generate
);

    logic [3:0] p, g;
    logic [4:0] c;

    assign p = a ^ b;
    assign g = a & b;
    assign c[0] = cin;

    // CLA carry equations
    assign c[1] = g[0] | (p[0] & c[0]);
    assign c[2] = g[1] | (p[1] & g[0]) | (p[1] & p[0] & c[0]);
    assign c[3] = g[2] | (p[2] & g[1]) | (p[2] & p[1] & g[0]) |
                  (p[2] & p[1] & p[0] & c[0]);
    assign c[4] = g[3] | (p[3] & g[2]) | (p[3] & p[2] & g[1]) |
                  (p[3] & p[2] & p[1] & g[0]) |
                  (p[3] & p[2] & p[1] & p[0] & c[0]);

    assign sum  = p ^ c[3:0];
    assign cout = c[4];
    assign pg   = &p;
    assign gg   = g[3] | (p[3] & g[2]) | (p[3] & p[2] & g[1]) |
                  (p[3] & p[2] & p[1] & g[0]);

endmodule

// 32-Bit CLA composed of eight 4-bit CLA blocks with a second-level lookahead
module cla_32bit (
    input  logic [31:0] a,
    input  logic [31:0] b,
    input  logic        cin,
    output logic [31:0] sum,
    output logic        cout
);

    logic [7:0] pg, gg;
    logic [8:0] c_group;
    logic [7:0] cout_internal;

    assign c_group[0] = cin;

    // Second-level carry lookahead across the eight 4-bit blocks
    genvar i;
    generate
        for (i = 0; i < 8; i++) begin : gen_cla
            cla_4bit u_cla4 (
                .a    (a[4*i+3 : 4*i]),
                .b    (b[4*i+3 : 4*i]),
                .cin  (c_group[i]),
                .sum  (sum[4*i+3 : 4*i]),
                .cout (cout_internal[i]),
                .pg   (pg[i]),
                .gg   (gg[i])
            );

            assign c_group[i+1] = gg[i] | (pg[i] & c_group[i]);
        end
    endgenerate

    assign cout = c_group[8];

endmodule
