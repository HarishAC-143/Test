// =============================================================================
// Example 2 — FIXED: Latch and Combinational Loop Issues Resolved
// =============================================================================
// Compare with: examples/lint_issues/latch_and_combo.v
//
// All issues addressed:
//   [FIXED] W_LATCH      — Added default/else branches
//   [FIXED] W_COMBO_LOOP — Broken loop with registered output
//   [FIXED] SYNTH_5130   — Removed non-synthesizable constructs
//   [FIXED] W_MULTI_DRIVE— Ensured single driver per signal
// =============================================================================

module latch_and_combo_fixed (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [1:0]  sel,
    input  wire [7:0]  data_a,
    input  wire [7:0]  data_b,
    input  wire [7:0]  data_c,
    output reg  [7:0]  mux_out,
    output reg  [7:0]  result,
    output reg  [7:0]  feedback_out
);

    // FIX 1: Added default case to prevent latch inference.
    // All possible values of 'sel' are now covered.
    always @(*) begin
        case (sel)
            2'b00:   mux_out = data_a;
            2'b01:   mux_out = data_b;
            2'b10:   mux_out = data_c;
            default: mux_out = 8'd0;  // Explicit default prevents latch
        endcase
    end

    // FIX 2: Added else clause to prevent latch inference on 'result'.
    always @(*) begin
        if (sel == 2'b00)
            result = data_a + data_b;
        else if (sel == 2'b01)
            result = data_a - data_b;
        else if (sel == 2'b10)
            result = data_a & data_b;
        else
            result = 8'd0;  // Explicit else prevents latch
    end

    // FIX 3: Broken combinational feedback loop by registering the output.
    // The feedback path now goes through a flip-flop, providing a
    // well-defined timing boundary.
    wire [7:0] combo_node;
    assign combo_node = data_a ^ feedback_out;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            feedback_out <= 8'd0;
        else
            feedback_out <= combo_node | data_b;
    end

    // FIX 4: Removed initial block and #delay — these are non-synthesizable.
    // If initialization is needed, use the reset path (above) instead.

endmodule
