// =============================================================================
// SpyGlass CDC Fix: Combo Before Synchronizer (Ac_cdc04) — Corrected
// =============================================================================
//
// The combinational logic is moved AFTER the synchronizer (into the
// destination domain) so that only registered signals from the source
// domain feed the synchronizer inputs directly. Each source signal
// is synchronized independently, and the combining logic operates
// on the synchronized outputs.
// =============================================================================

module combo_before_sync_fixed (
    input  clk_a,
    input  rst_a_n,
    input  clk_b,
    input  rst_b_n,
    input  sig_a1,
    input  sig_a2,
    output synced_out
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

    // Synchronize each signal independently — no combinational logic
    // between source registers and synchronizer inputs.
    reg sync1_a1, sync2_a1;
    reg sync1_a2, sync2_a2;

    always @(posedge clk_b or negedge rst_b_n) begin
        if (!rst_b_n) begin
            sync1_a1 <= 1'b0;
            sync2_a1 <= 1'b0;
            sync1_a2 <= 1'b0;
            sync2_a2 <= 1'b0;
        end else begin
            sync1_a1 <= reg_a1;
            sync2_a1 <= sync1_a1;
            sync1_a2 <= reg_a2;
            sync2_a2 <= sync1_a2;
        end
    end

    // Combinational logic AFTER synchronization — safe, no glitch risk
    // on the CDC path itself.
    assign synced_out = sync2_a1 | sync2_a2;

endmodule
