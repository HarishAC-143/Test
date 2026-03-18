// =============================================================================
// Example 6 — FIXED: No Combinational Logic Before Synchronizer
// =============================================================================
// Compare with: examples/cdc_issues/cdc_combo_before_sync.v
//
// Fix: Perform the combinational logic (AND gate) in the SOURCE domain
// and register the result BEFORE it crosses to the destination domain.
// This ensures only a clean, registered signal enters the synchronizer.
//
// Rule of thumb: The input to a synchronizer's first FF must come
// directly from a flip-flop in the source domain — no logic in between.
// =============================================================================

module cdc_combo_fixed (
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

    // =========================================================================
    // Clock Domain A — Perform logic and REGISTER result
    // =========================================================================
    reg req_reg_a;
    reg mode_reg_a;
    reg combined_reg_a;   // Registered output — glitch-free

    always @(posedge clk_a or negedge rst_a_n) begin
        if (!rst_a_n) begin
            req_reg_a      <= 1'b0;
            mode_reg_a     <= 1'b0;
            combined_reg_a <= 1'b0;
        end else begin
            req_reg_a      <= req;
            mode_reg_a     <= mode;
            combined_reg_a <= req & mode;  // Logic performed, then registered
        end
    end

    // =========================================================================
    // Clock Domain B — Clean 2-FF synchronizer
    // =========================================================================
    // combined_reg_a is a registered signal from domain A.
    // No combinational logic between it and the synchronizer.
    reg sync_stage1;

    always @(posedge clk_b or negedge rst_b_n) begin
        if (!rst_b_n) begin
            sync_stage1 <= 1'b0;
            req_sync_b  <= 1'b0;
        end else begin
            sync_stage1 <= combined_reg_a;   // Direct FF-to-FF: clean
            req_sync_b  <= sync_stage1;
        end
    end

endmodule
