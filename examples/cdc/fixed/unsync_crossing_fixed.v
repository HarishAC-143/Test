// =============================================================================
// SpyGlass CDC Fix: Unsynchronized Crossing (Ac_cdc01) — Corrected
// =============================================================================
//
// A proper two-flop synchronizer is added in the destination clock domain
// to resolve metastability before the signal is used by downstream logic.
// =============================================================================

module unsync_crossing_fixed (
    input  clk_a,
    input  rst_a_n,
    input  clk_b,
    input  rst_b_n,
    input  data_in,
    output data_out
);

    reg data_reg_a;

    // Source domain register
    always @(posedge clk_a or negedge rst_a_n) begin
        if (!rst_a_n)
            data_reg_a <= 1'b0;
        else
            data_reg_a <= data_in;
    end

    // Two-flop synchronizer in destination domain
    // sync_ff1: may go metastable, but has a full clock period to resolve
    // sync_ff2: captures the resolved value of sync_ff1
    reg sync_ff1, sync_ff2;

    always @(posedge clk_b or negedge rst_b_n) begin
        if (!rst_b_n) begin
            sync_ff1 <= 1'b0;
            sync_ff2 <= 1'b0;
        end else begin
            sync_ff1 <= data_reg_a;  // First stage — absorbs metastability
            sync_ff2 <= sync_ff1;    // Second stage — stable output
        end
    end

    assign data_out = sync_ff2;

endmodule
