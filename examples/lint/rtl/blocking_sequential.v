// =============================================================================
// SpyGlass Lint Example: Blocking Assignment in Sequential Logic (W71)
// =============================================================================
//
// SpyGlass Rule: W71
// Severity:      Warning
// Category:      Simulation-Synthesis Mismatch
//
// Using blocking assignments (=) in a clocked always block causes
// race conditions in simulation and can lead to different behavior
// between simulation and synthesis. Sequential logic should always
// use non-blocking assignments (<=).
//
// Run with: current_goal lint/lint_rtl
// =============================================================================

// W71 VIOLATION: Blocking assignments in sequential always block
module pipeline_buggy (
    input        clk,
    input        rst_n,
    input  [7:0] data_in,
    output [7:0] data_out
);

    reg [7:0] stage1, stage2, stage3;

    // W71: All assignments here use blocking (=) instead of non-blocking (<=).
    //
    // Because blocking assignments execute sequentially within the block:
    //   stage1 = data_in   → stage1 immediately gets data_in
    //   stage2 = stage1    → stage2 gets the NEW stage1 (= data_in)
    //   stage3 = stage2    → stage3 gets the NEW stage2 (= data_in)
    //
    // Result: All three stages get data_in in the SAME cycle!
    // The pipeline is effectively collapsed to zero stages.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            stage1 = 8'h0;
            stage2 = 8'h0;
            stage3 = 8'h0;
        end else begin
            stage1 = data_in;   // W71
            stage2 = stage1;    // W71 — gets new value of stage1
            stage3 = stage2;    // W71 — gets new value of stage2
        end
    end

    assign data_out = stage3;

endmodule


// Related issue: mixing blocking and non-blocking in the same block
module mixed_assignment_buggy (
    input        clk,
    input        rst_n,
    input  [7:0] a, b,
    output reg [7:0] sum,
    output reg       overflow
);

    // W71: Mixing blocking and non-blocking in sequential logic.
    // This makes the evaluation order ambiguous and tool-dependent.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sum      <= 8'h0;
            overflow <= 1'b0;
        end else begin
            sum = a + b;                 // W71: blocking
            overflow <= (a + b > 8'hFF); // non-blocking
        end
    end

endmodule
