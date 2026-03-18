// =============================================================================
// SpyGlass CDC Example: Pulse Synchronizer
// =============================================================================
//
// Transfers a single-cycle pulse from one clock domain to another.
//
// The challenge: a pulse in a fast domain may be shorter than a clock
// period in the slow domain, so it might be missed entirely by a simple
// two-flop synchronizer.
//
// Solution: convert the pulse to a level toggle in the source domain,
// synchronize the level, then detect the edge in the destination domain.
//
//   clk_a domain:         clk_b domain:
//   pulse → toggle  ───▶  sync → edge detect → pulse_out
//
// Run with: current_goal cdc/cdc_verify
// =============================================================================

module pulse_sync (
    input  clk_a,
    input  rst_a_n,
    input  clk_b,
    input  rst_b_n,
    input  pulse_in,    // Single-cycle pulse in clk_a domain
    output pulse_out    // Single-cycle pulse in clk_b domain
);

    // =========================================================================
    // Source Domain (clk_a): Convert pulse to level toggle
    // =========================================================================
    reg toggle_a;

    always @(posedge clk_a or negedge rst_a_n) begin
        if (!rst_a_n)
            toggle_a <= 1'b0;
        else if (pulse_in)
            toggle_a <= ~toggle_a;  // Toggle on each pulse
    end

    // =========================================================================
    // Two-Flop Synchronizer: Synchronize toggle into clk_b domain
    // =========================================================================
    reg sync_ff1, sync_ff2, sync_ff3;

    always @(posedge clk_b or negedge rst_b_n) begin
        if (!rst_b_n) begin
            sync_ff1 <= 1'b0;
            sync_ff2 <= 1'b0;
            sync_ff3 <= 1'b0;
        end else begin
            sync_ff1 <= toggle_a;    // Synchronizer stage 1
            sync_ff2 <= sync_ff1;    // Synchronizer stage 2
            sync_ff3 <= sync_ff2;    // Delay for edge detection
        end
    end

    // =========================================================================
    // Destination Domain (clk_b): Edge detect to regenerate pulse
    // =========================================================================
    // XOR of sync_ff2 and sync_ff3 produces a single-cycle pulse
    // whenever the synchronized toggle changes state.
    assign pulse_out = sync_ff2 ^ sync_ff3;

endmodule
