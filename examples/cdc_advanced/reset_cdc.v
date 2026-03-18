//-----------------------------------------------------------------------------
// Example: Reset Domain Crossing (RDC)
//
// SpyGlass Rules Triggered:
//   Ac_rdc01 - Reset signal crosses clock domain without synchronizer
//   Ac_rdc02 - Asynchronous reset deassertion not synchronized
//   Ac_cdc01 - General CDC on reset path
//
// Reset crossing is a special case of CDC. The key issue:
//   - Async reset ASSERTION is safe (it's level-triggered, no timing req)
//   - Async reset DEASSERTION must be synchronous to the clock domain
//     (otherwise violates recovery/removal time → metastability)
//
// The standard solution is a "reset synchronizer" — an async-assert,
// sync-deassert reset bridge.
//-----------------------------------------------------------------------------

module reset_cdc_bad (
    input  wire clk_a,
    input  wire clk_b,
    input  wire ext_rst_n,    // External async reset
    output reg  data_a,
    output reg  data_b
);

    // BUG: Same async reset used directly in both clock domains
    // Reset assertion (ext_rst_n goes low) is fine — asynchronous, level-based
    // Reset deassertion (ext_rst_n goes high) is the problem:
    //   - If deassertion occurs near clk_b's active edge, the flip-flop
    //     may violate recovery/removal time → metastable output
    //   - Some flops may come out of reset one cycle before others
    //     → inconsistent initial state

    always @(posedge clk_a or negedge ext_rst_n) begin
        if (!ext_rst_n)
            data_a <= 1'b0;
        else
            data_a <= 1'b1;
    end

    always @(posedge clk_b or negedge ext_rst_n) begin
        if (!ext_rst_n)
            data_b <= 1'b0;          // Ac_rdc02: reset deassertion not synced!
        else
            data_b <= 1'b1;
    end

endmodule


//-----------------------------------------------------------------------------
// Reset Synchronizer: Async Assert, Sync Deassert
//
// Ensures that reset deassertion is synchronous to the target clock,
// preventing recovery/removal time violations.
//-----------------------------------------------------------------------------
module reset_sync (
    input  wire clk,          // Target clock domain
    input  wire rst_async_n,  // Incoming async reset (active low)
    output wire rst_sync_n    // Synchronized reset output (active low)
);

    (* async_reg = "true" *)
    reg rst_pipe1, rst_pipe2;

    always @(posedge clk or negedge rst_async_n) begin
        if (!rst_async_n) begin
            rst_pipe1 <= 1'b0;   // Async assert (immediate)
            rst_pipe2 <= 1'b0;   // Async assert (immediate)
        end else begin
            rst_pipe1 <= 1'b1;   // Sync deassert (aligned to clk)
            rst_pipe2 <= rst_pipe1;
        end
    end

    assign rst_sync_n = rst_pipe2;

endmodule


module reset_cdc_good (
    input  wire clk_a,
    input  wire clk_b,
    input  wire ext_rst_n,
    output reg  data_a,
    output reg  data_b
);

    // FIX: Generate a synchronized reset for each clock domain
    wire rst_a_n, rst_b_n;

    reset_sync u_rst_sync_a (
        .clk        (clk_a),
        .rst_async_n(ext_rst_n),
        .rst_sync_n (rst_a_n)
    );

    reset_sync u_rst_sync_b (
        .clk        (clk_b),
        .rst_async_n(ext_rst_n),
        .rst_sync_n (rst_b_n)
    );

    // Each domain uses its own synchronized reset
    always @(posedge clk_a or negedge rst_a_n) begin
        if (!rst_a_n)
            data_a <= 1'b0;
        else
            data_a <= 1'b1;
    end

    always @(posedge clk_b or negedge rst_b_n) begin
        if (!rst_b_n)
            data_b <= 1'b0;
        else
            data_b <= 1'b1;
    end

endmodule
