// =============================================================================
// Counter — Fixed Version (All Lint Issues Resolved)
// =============================================================================
// This is the corrected version of counter_with_issues.v.
// All SpyGlass lint violations have been resolved.
// =============================================================================

module counter_fixed (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       enable,
    input  wire [7:0] load_value,     // Fixed: matched to counter width
    input  wire       load,
    output reg  [7:0] count,
    output wire       overflow
);

    // Fix 1: Removed unused debug_count signal (was W_0123)
    // Fix 2: Removed undriven internal_enable (was W_0124) — use 'enable' directly

    // Fix 3: load_value width matched to count (was W_0164)
    // Fix 4: Non-blocking assignments in sequential block (was W_0528)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            count <= 8'h00;
        else if (load)
            count <= load_value;
        else if (enable)
            count <= count + 8'd1;
    end

    // Fix 5: Use always @(*) for complete sensitivity list (was W_0391)
    reg overflow_reg;
    always @(*) begin
        if (enable && count == 8'hFF)
            overflow_reg = 1'b1;
        else
            overflow_reg = 1'b0;
    end

    assign overflow = overflow_reg;

endmodule
