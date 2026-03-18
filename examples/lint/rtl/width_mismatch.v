// =============================================================================
// SpyGlass Lint Example: Width Mismatch (W164)
// =============================================================================
//
// SpyGlass Rule: W164
// Severity:      Warning
// Category:      Connectivity / Arithmetic
//
// Width mismatches in port connections or assignments cause silent
// truncation or zero-extension, potentially losing data. SpyGlass W164
// flags these mismatches so designers can decide if the truncation is
// intentional or a bug.
//
// Run with: current_goal lint/lint_rtl
// =============================================================================

// Helper module: 9-bit adder
module adder (
    input  [7:0] a,
    input  [7:0] b,
    output [8:0] sum
);
    assign sum = a + b;
endmodule


// W164 VIOLATION: 9-bit port connected to 8-bit net
module top_width_buggy (
    input  [7:0] x,
    input  [7:0] y,
    output [7:0] result  // Only 8 bits — carry is silently lost!
);

    // W164: Port 'sum' is 9 bits wide but 'result' is only 8 bits.
    // The MSB (carry) is truncated without any explicit indication.
    adder u_adder (
        .a   (x),
        .b   (y),
        .sum (result)       // Width mismatch: 9 → 8
    );

endmodule


// W164 VIOLATION: assignment width mismatch
module width_assign_buggy (
    input  [15:0] wide_data,
    output reg [7:0] narrow_data
);

    // W164: 16-bit value assigned to 8-bit register.
    // Upper 8 bits are silently discarded.
    always @(*) begin
        narrow_data = wide_data;  // Truncation: bits [15:8] lost
    end

endmodule


// W164 VIOLATION: concatenation with wrong bit count
module concat_buggy (
    input  [3:0] nibble_a,
    input  [3:0] nibble_b,
    output [9:0] wide_out   // 10 bits
);
    // {nibble_a, nibble_b} is only 8 bits, connected to 10-bit port.
    // Upper 2 bits are implicitly zero-filled.
    assign wide_out = {nibble_a, nibble_b};  // W164: 8 → 10

endmodule
