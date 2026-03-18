// =============================================================================
// Example 5: CDC — Multi-Bit Signal with Incorrect Synchronization
// =============================================================================
// A 4-bit counter crosses from clk_a to clk_b. The designer attempted
// to synchronize each bit independently using 2-FF synchronizers — but
// this is WRONG for multi-bit signals.
//
// SpyGlass CDC will report:
//   Ac_cdc02 — "Multi-bit signal 'counter_a' crosses from 'clk_a' to
//               'clk_b' without proper multi-bit synchronization scheme."
//
// Problem: Individual bits can be captured on different clk_b edges.
// Example: counter_a transitions from 4'b0111 to 4'b1000:
//   - bit[3] might be captured as 1 (new value)
//   - bit[2:0] might be captured as 111 (old value)
//   - Result: 4'b1111 (invalid — never actually existed!)
// =============================================================================

module cdc_multibit_bad (
    // Domain A
    input  wire       clk_a,
    input  wire       rst_a_n,
    input  wire       count_en,

    // Domain B
    input  wire       clk_b,
    input  wire       rst_b_n,
    output reg [3:0]  counter_b_sync
);

    // ----- Clock Domain A -----
    reg [3:0] counter_a;

    always @(posedge clk_a or negedge rst_a_n) begin
        if (!rst_a_n)
            counter_a <= 4'd0;
        else if (count_en)
            counter_a <= counter_a + 1'b1;
    end

    // ----- Clock Domain B -----

    // BAD: Per-bit 2-FF synchronizers on a multi-bit bus.
    // Each bit is synchronized independently — bits may arrive
    // at different clk_b edges, creating transient invalid values.
    reg [3:0] sync_stage1, sync_stage2;

    always @(posedge clk_b or negedge rst_b_n) begin
        if (!rst_b_n) begin
            sync_stage1   <= 4'd0;
            sync_stage2   <= 4'd0;
            counter_b_sync <= 4'd0;
        end else begin
            sync_stage1   <= counter_a;      // VIOLATION: Ac_cdc02
            sync_stage2   <= sync_stage1;
            counter_b_sync <= sync_stage2;
        end
    end

    // CORRECT approach: Convert counter_a to Gray code BEFORE crossing,
    // then decode back to binary AFTER synchronization.
    // See: examples/cdc_fixed/cdc_multibit_gray.v

endmodule
