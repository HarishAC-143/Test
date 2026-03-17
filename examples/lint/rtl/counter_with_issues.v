// =============================================================================
// Counter with Common Lint Issues
// =============================================================================
// This module intentionally contains multiple lint violations for educational
// purposes. Each violation is annotated with the SpyGlass rule it triggers.
// Compare with counter_fixed.v for the corrected version.
// =============================================================================

module counter_with_issues (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        enable,
    input  wire [15:0] load_value,    // 16-bit input
    input  wire        load,
    output reg  [7:0]  count,
    output wire        overflow
);

    // -------------------------------------------------------------------------
    // Issue 1: W_0123 — Unloaded signal (driven but never read)
    // -------------------------------------------------------------------------
    reg [7:0] debug_count;

    // -------------------------------------------------------------------------
    // Issue 2: W_0124 — Undriven signal (read but never driven)
    // -------------------------------------------------------------------------
    wire internal_enable;

    // -------------------------------------------------------------------------
    // Issue 3: W_0164 — Width mismatch / truncation
    //          load_value is 16 bits, count is 8 bits
    // -------------------------------------------------------------------------

    // -------------------------------------------------------------------------
    // Issue 4: W_0528 — Blocking assignment in sequential always block
    // -------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count = 8'h00;        // BAD: blocking in sequential
            debug_count = 8'h00;  // BAD: blocking in sequential
        end else if (load) begin
            count = load_value;   // BAD: blocking + truncation (16→8 bits)
        end else if (internal_enable) begin  // Reads undriven signal
            count = count + 1;    // BAD: blocking in sequential
        end
        debug_count = count;      // Driven but never read
    end

    // -------------------------------------------------------------------------
    // Issue 5: W_0391 — Incomplete sensitivity list
    // -------------------------------------------------------------------------
    reg overflow_reg;
    always @(count) begin         // Missing 'enable' from sensitivity list
        if (enable && count == 8'hFF)
            overflow_reg = 1'b1;
        else
            overflow_reg = 1'b0;
    end

    assign overflow = overflow_reg;

endmodule
