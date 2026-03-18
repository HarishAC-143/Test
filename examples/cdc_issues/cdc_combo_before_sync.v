// =============================================================================
// Example 6: CDC — Combinational Logic Before Synchronizer
// =============================================================================
// Combinational logic exists between the source domain flip-flop and the
// first stage of the synchronizer. This can introduce glitches that
// propagate through the synchronizer.
//
// SpyGlass CDC will report:
//   Ac_cdc03 — "Combinational logic found on CDC path before synchronizer."
//   Ac_cdc06 — "Potential glitch on CDC path."
//
// Problem: Combinational logic can produce transient (glitch) values when
// its inputs change. If a glitch arrives at the synchronizer input
// near the clock edge, it can be captured as a valid transition.
// =============================================================================

module cdc_combo_before_sync (
    // Domain A
    input  wire       clk_a,
    input  wire       rst_a_n,
    input  wire       req,
    input  wire       mode,

    // Domain B
    input  wire       clk_b,
    input  wire       rst_b_n,
    output reg        req_sync_b
);

    // ----- Clock Domain A -----
    reg req_reg_a;
    reg mode_reg_a;

    always @(posedge clk_a or negedge rst_a_n) begin
        if (!rst_a_n) begin
            req_reg_a  <= 1'b0;
            mode_reg_a <= 1'b0;
        end else begin
            req_reg_a  <= req;
            mode_reg_a <= mode;
        end
    end

    // BUG: Combinational logic between source FF and synchronizer.
    //
    // 'combined_signal' is a combinational function of two registered signals.
    // When req_reg_a and mode_reg_a change at different times (relative to
    // clk_a), 'combined_signal' can glitch.
    //
    // Example: req_reg_a transitions 0→1 while mode_reg_a transitions 1→0
    //   - Momentarily, both signals may be 1 or both 0 (depending on routing)
    //   - The AND gate output glitches
    //   - If the glitch aligns with clk_b edge → metastability or wrong value
    wire combined_signal;
    assign combined_signal = req_reg_a & mode_reg_a;  // Glitch-prone!

    // ----- Clock Domain B -----
    reg sync_stage1;

    always @(posedge clk_b or negedge rst_b_n) begin
        if (!rst_b_n) begin
            sync_stage1 <= 1'b0;
            req_sync_b  <= 1'b0;
        end else begin
            sync_stage1 <= combined_signal;  // VIOLATION: Ac_cdc03
            req_sync_b  <= sync_stage1;
        end
    end

endmodule
