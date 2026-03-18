//-----------------------------------------------------------------------------
// Example: Unintended Latch Inference
//
// SpyGlass Rules Triggered:
//   W_116   - Latch inferred for signal
//   STARC-2.1.4.4 - Incomplete if/case in combinational block
//
// This file demonstrates two versions:
//   1. BAD  — incomplete assignments create latches
//   2. GOOD — fully specified assignments, no latches
//-----------------------------------------------------------------------------

module latch_inference_bad (
    input  wire       enable,
    input  wire       mode,
    input  wire [7:0] data_a,
    input  wire [7:0] data_b,
    output reg  [7:0] result,
    output reg  [7:0] mux_out
);

    // BUG: Missing 'else' branch — SpyGlass flags W_116
    // When enable=0, 'result' must hold its value → latch inferred
    always @(*) begin
        if (enable)
            result = data_a;
    end

    // BUG: Incomplete case — not all values of 'mode' are covered
    always @(*) begin
        case (mode)
            1'b0: mux_out = data_a;
            // 1'b1 is missing → latch for mux_out
        endcase
    end

endmodule


module latch_inference_good (
    input  wire       enable,
    input  wire       mode,
    input  wire [7:0] data_a,
    input  wire [7:0] data_b,
    output reg  [7:0] result,
    output reg  [7:0] mux_out
);

    // FIX: Provide an else branch — no latch
    always @(*) begin
        if (enable)
            result = data_a;
        else
            result = 8'b0;
    end

    // FIX: Add default case — no latch
    always @(*) begin
        case (mode)
            1'b0:    mux_out = data_a;
            default: mux_out = data_b;
        endcase
    end

endmodule
