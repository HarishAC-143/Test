// =============================================================================
// SpyGlass CDC Example: Combinational Logic Before Synchronizer (Ac_cdc04)
// =============================================================================
//
// SpyGlass Rule: Ac_cdc04 / Ac_glitch01
// Severity:      Warning
// Category:      Clock Domain Crossing
//
// Combinational logic (gates) placed on the CDC path BEFORE the first
// synchronizer flip-flop can generate short glitches. These glitches
// occur because different input signals to the combinational logic may
// arrive at slightly different times. If a glitch is present when the
// destination clock samples, the synchronizer captures a corrupted value.
//
// Run with: current_goal cdc/cdc_verify
// =============================================================================

module combo_before_sync (
    input  clk_a,
    input  rst_a_n,
    input  clk_b,
    input  rst_b_n,
    input  sig_a1,
    input  sig_a2,
    output reg synced_out
);

    reg reg_a1, reg_a2;

    // Source domain registers
    always @(posedge clk_a or negedge rst_a_n) begin
        if (!rst_a_n) begin
            reg_a1 <= 1'b0;
            reg_a2 <= 1'b0;
        end else begin
            reg_a1 <= sig_a1;
            reg_a2 <= sig_a2;
        end
    end

    // Ac_cdc04 / Ac_glitch01 VIOLATION:
    // Combinational OR gate between source domain registers and
    // destination domain synchronizer. If reg_a1 and reg_a2 change
    // at slightly different times, the OR gate output may glitch
    // momentarily, and that glitch can be captured by sync_ff1.
    wire combo_out = reg_a1 | reg_a2;  // Glitch-prone!

    reg sync_ff1, sync_ff2;

    always @(posedge clk_b or negedge rst_b_n) begin
        if (!rst_b_n) begin
            sync_ff1 <= 1'b0;
            sync_ff2 <= 1'b0;
        end else begin
            sync_ff1 <= combo_out;  // Samples glitchy signal!
            sync_ff2 <= sync_ff1;
        end
    end

    assign synced_out = sync_ff2;

endmodule
