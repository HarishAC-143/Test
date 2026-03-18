// =============================================================================
// Practical Example: Reset Synchronizer
// =============================================================================
// Demonstrates proper synchronization of asynchronous reset de-assertion.
//
// Problem:
//   Asynchronous reset assertion is inherently safe — all flops reset
//   immediately regardless of clock. However, reset DE-ASSERTION is
//   dangerous: if it occurs near a clock edge, some flops may come out
//   of reset one cycle before others, causing functional issues.
//
// Solution: "Asynchronous assert, synchronous de-assert" pattern.
//   - Reset asserts immediately (asynchronous) — no clock needed
//   - Reset de-asserts on a clock edge (synchronous) — all flops
//     release together
//
// SpyGlass checks:
//   Ac_unsync_rst  — flags unsynchronized reset de-assertion
//   Ac_cdc07       — reset crossing domain issue
// =============================================================================

// -----------------------------------------------------------------------------
// Module: reset_synchronizer
// Synchronizes asynchronous reset de-assertion to a target clock domain.
// The output rst_sync_n asserts asynchronously and de-asserts synchronously.
// -----------------------------------------------------------------------------
module reset_synchronizer #(
    parameter SYNC_STAGES = 2    // Number of synchronizer stages (2 is standard)
) (
    input  wire clk,             // Target clock domain
    input  wire rst_async_n,     // Asynchronous reset input (active low)
    output wire rst_sync_n       // Synchronized reset output (active low)
);

    // Synchronizer chain — all stages share the same async reset
    // so they assert immediately. De-assertion ripples through the chain
    // synchronously on clk edges.
    reg [SYNC_STAGES-1:0] sync_chain;

    // The key insight: negedge rst_async_n in the sensitivity list provides
    // immediate assertion. The sequential assignment to sync_chain provides
    // synchronous de-assertion.
    always @(posedge clk or negedge rst_async_n) begin
        if (!rst_async_n)
            sync_chain <= {SYNC_STAGES{1'b0}};  // Assert: all stages go low
        else
            sync_chain <= {sync_chain[SYNC_STAGES-2:0], 1'b1};  // De-assert: shift in 1's
    end

    assign rst_sync_n = sync_chain[SYNC_STAGES-1];

endmodule

// -----------------------------------------------------------------------------
// Module: multi_domain_reset_example
// Demonstrates using reset_synchronizer in a system with two clock domains,
// each needing its own synchronized copy of the master reset.
// -----------------------------------------------------------------------------
module multi_domain_reset_example (
    input  wire       clk_fast,     // 200 MHz domain
    input  wire       clk_slow,     // 50 MHz domain
    input  wire       master_rst_n, // Asynchronous master reset
    input  wire [7:0] data_in,
    output reg  [7:0] data_fast,
    output reg  [7:0] data_slow
);

    // Generate domain-specific synchronized resets
    wire rst_fast_n;
    wire rst_slow_n;

    reset_synchronizer #(.SYNC_STAGES(2)) u_rst_fast (
        .clk        (clk_fast),
        .rst_async_n(master_rst_n),
        .rst_sync_n (rst_fast_n)
    );

    reset_synchronizer #(.SYNC_STAGES(3)) u_rst_slow (
        .clk        (clk_slow),
        .rst_async_n(master_rst_n),
        .rst_sync_n (rst_slow_n)
    );

    // Fast domain logic — uses rst_fast_n (sync to clk_fast)
    always @(posedge clk_fast or negedge rst_fast_n) begin
        if (!rst_fast_n)
            data_fast <= 8'd0;
        else
            data_fast <= data_in;
    end

    // Slow domain logic — uses rst_slow_n (sync to clk_slow)
    always @(posedge clk_slow or negedge rst_slow_n) begin
        if (!rst_slow_n)
            data_slow <= 8'd0;
        else
            data_slow <= data_in;
    end

endmodule
