// =============================================================================
// Example 1: Counter with Common Lint Issues
// =============================================================================
// This module intentionally contains multiple lint violations to demonstrate
// how SpyGlass Lint detects and reports common RTL coding mistakes.
//
// SpyGlass will report the following on this file:
//   W_REGS_ARST       — Flip-flops without asynchronous reset
//   W_UNDRIVEN        — Signal declared but never driven
//   W_UNUSED          — Signal driven but never read
//   W_ASSIGN_TRUNCATE — Width mismatch (RHS wider than LHS)
//   W_SENSITIVITY     — Incomplete sensitivity list
//   W_CONNECTED_X     — Port connected to X
// =============================================================================

module counter_with_issues (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        enable,
    input  wire [7:0]  load_val,
    input  wire        load_en,
    output reg  [7:0]  count,
    output wire        overflow,
    output wire [3:0]  upper_nibble
);

    // -------------------------------------------------------------------------
    // ISSUE 1: W_UNDRIVEN — 'debug_sig' is declared but never assigned a value.
    // SpyGlass reports: "Signal 'debug_sig' is not driven."
    // -------------------------------------------------------------------------
    wire [7:0] debug_sig;

    // -------------------------------------------------------------------------
    // ISSUE 2: W_UNUSED — 'internal_flag' is assigned but its value is never
    // read by any downstream logic or output port.
    // SpyGlass reports: "Signal 'internal_flag' is not read."
    // -------------------------------------------------------------------------
    reg internal_flag;

    // -------------------------------------------------------------------------
    // ISSUE 3: W_REGS_ARST — This always block uses only posedge clk.
    // The flip-flop 'count' has no asynchronous reset, so its initial
    // value at power-up is unknown (X in simulation).
    // SpyGlass reports: "Register 'count' does not have asynchronous reset."
    // -------------------------------------------------------------------------
    always @(posedge clk) begin
        if (load_en)
            count <= load_val;
        else if (enable)
            count <= count + 1'b1;
    end

    // -------------------------------------------------------------------------
    // ISSUE 4: W_ASSIGN_TRUNCATE — The RHS is 9 bits (8-bit count + 1-bit carry)
    // but the LHS 'overflow' is only 1 bit. The upper bits are silently truncated.
    // SpyGlass reports: "Truncation in assignment to 'overflow'."
    // -------------------------------------------------------------------------
    assign overflow = count + 8'd1;

    // -------------------------------------------------------------------------
    // ISSUE 5: W_SENSITIVITY — In Verilog-2001 style, this combinational block
    // uses an explicit sensitivity list that is missing 'count'.
    // If 'count' changes, the block will not re-evaluate, causing
    // simulation/synthesis mismatch.
    // SpyGlass reports: "Incomplete sensitivity list."
    //
    // Fix: Use always @(*) or always_comb.
    // -------------------------------------------------------------------------
    always @(enable) begin
        internal_flag = (count > 8'd200) & enable;
    end

    // -------------------------------------------------------------------------
    // ISSUE 6: W_CONNECTED_X — 'upper_nibble' is partially driven.
    // Only bits [3:2] are assigned; bits [1:0] are left unconnected.
    // SpyGlass reports: "Bits [1:0] of 'upper_nibble' are not driven."
    // -------------------------------------------------------------------------
    assign upper_nibble[3:2] = count[7:6];

endmodule
