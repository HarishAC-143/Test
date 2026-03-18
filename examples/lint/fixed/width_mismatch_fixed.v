// =============================================================================
// SpyGlass Lint Fix: Width Mismatch (W164) — Corrected
// =============================================================================
//
// Port connections and assignments now have matching widths, with
// explicit handling of any truncation or extension.
// =============================================================================

module adder (
    input  [7:0] a,
    input  [7:0] b,
    output [8:0] sum
);
    assign sum = a + b;
endmodule


module top_width_fixed (
    input  [7:0] x,
    input  [7:0] y,
    output [7:0] result,
    output       carry
);

    wire [8:0] full_sum;

    adder u_adder (
        .a   (x),
        .b   (y),
        .sum (full_sum)  // Widths match: both 9 bits
    );

    assign result = full_sum[7:0];  // Explicit slice
    assign carry  = full_sum[8];    // Carry explicitly extracted

endmodule


module width_assign_fixed (
    input  [15:0] wide_data,
    output reg [7:0] narrow_data
);

    // Explicit bit-select makes the truncation intentional and clear
    always @(*) begin
        narrow_data = wide_data[7:0];
    end

endmodule


module concat_fixed (
    input  [3:0] nibble_a,
    input  [3:0] nibble_b,
    output [9:0] wide_out
);
    // Pad with explicit zero bits to match the 10-bit output width
    assign wide_out = {2'b00, nibble_a, nibble_b};

endmodule
