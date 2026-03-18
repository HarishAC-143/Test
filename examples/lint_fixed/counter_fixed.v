// =============================================================================
// Example 1 — FIXED: Counter with All Lint Issues Resolved
// =============================================================================
// Compare with: examples/lint_issues/counter_with_issues.v
//
// All issues addressed:
//   [FIXED] W_REGS_ARST       — Added asynchronous reset
//   [FIXED] W_UNDRIVEN        — Removed undriven signal (or connected it)
//   [FIXED] W_UNUSED          — Removed unused signal (or connected to output)
//   [FIXED] W_ASSIGN_TRUNCATE — Corrected width mismatch
//   [FIXED] W_SENSITIVITY     — Using always @(*)
//   [FIXED] W_CONNECTED_X     — All output bits driven
// =============================================================================

module counter_fixed (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        enable,
    input  wire [7:0]  load_val,
    input  wire        load_en,
    output reg  [7:0]  count,
    output wire        overflow,
    output wire [3:0]  upper_nibble
);

    // FIX 1: Removed 'debug_sig' — it was declared but never driven.
    //         If debugging is needed, drive it explicitly or use a debug module.

    // FIX 2: Removed 'internal_flag' — it was assigned but never read.
    //         If the flag is needed, connect it to an output port or downstream logic.

    // FIX 3: Added asynchronous active-low reset.
    // The reset initializes 'count' to a known value at power-up.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            count <= 8'd0;
        else if (load_en)
            count <= load_val;
        else if (enable)
            count <= count + 1'b1;
    end

    // FIX 4: Corrected width — 'overflow' is now properly derived from the
    // carry-out of the 9-bit addition.
    wire [8:0] count_extended;
    assign count_extended = {1'b0, count} + 9'd1;
    assign overflow = count_extended[8];

    // FIX 5: Sensitivity list issue removed — we don't need the combinational
    // block for 'internal_flag' since it was unused.

    // FIX 6: All bits of 'upper_nibble' are explicitly driven.
    assign upper_nibble = count[7:4];

endmodule
