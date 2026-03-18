// =============================================================================
// SpyGlass Lint Example: Combinational Loop (W18)
// =============================================================================
//
// SpyGlass Rule: W18
// Severity:      Warning (often promoted to Error)
// Category:      Synthesis
//
// A combinational loop exists when the output of combinational logic
// feeds back to its own input without passing through a register.
// This creates an unstable circuit that oscillates in simulation and
// produces unpredictable behavior in hardware.
//
// Run with: current_goal lint/lint_rtl
// =============================================================================

// W18 VIOLATION: Direct combinational feedback
module combo_loop_buggy (
    input  a,
    input  b,
    output y
);

    wire mid;

    // y depends on mid, and mid depends on y.
    // This creates the loop: y → mid → y → mid → ...
    assign mid = a & y;    // y feeds back combinationally
    assign y   = mid | b;  // W18: combinational loop detected

endmodule


// W18 VIOLATION: Loop through multiple modules
module inv_gate (
    input  in,
    output out
);
    assign out = ~in;
endmodule

module loop_chain_buggy (
    input  enable,
    output oscillator
);
    wire w1, w2, w3;

    // Ring oscillator: w1 → w2 → w3 → w1
    inv_gate u1 (.in(w3),          .out(w1));  // W18
    inv_gate u2 (.in(w1),          .out(w2));
    inv_gate u3 (.in(w2 & enable), .out(w3));

    assign oscillator = w1;

endmodule


// W18 VIOLATION: Subtle loop through always block
module subtle_loop_buggy (
    input      sel,
    input      data_in,
    output reg data_out
);

    reg internal;

    // Loop: data_out → internal → data_out
    always @(*) begin
        internal = data_out & sel;     // reads data_out
        data_out = internal | data_in; // writes data_out → W18
    end

endmodule
