//-----------------------------------------------------------------------------
// Example: Multi-Driven Signals
//
// SpyGlass Rules Triggered:
//   W_263  - Signal driven from multiple always blocks
//   W_446  - Signal driven from multiple modules
//
// A signal should be driven from exactly one procedural block or one
// continuous assignment. Multiple drivers cause simulation races and
// synthesis errors.
//-----------------------------------------------------------------------------

module multidriven_bad (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       sel,
    input  wire [7:0] data_a,
    input  wire [7:0] data_b,
    output reg  [7:0] result
);

    // BUG: Two always blocks drive 'result'
    // Simulation behavior depends on block evaluation order (race condition)
    // Synthesis will produce an error or unpredictable hardware

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            result <= 8'b0;
        else if (sel)
            result <= data_a;   // Driver 1
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            result <= 8'b0;
        else if (!sel)
            result <= data_b;   // Driver 2 — W_263!
    end

endmodule


module multidriven_good (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       sel,
    input  wire [7:0] data_a,
    input  wire [7:0] data_b,
    output reg  [7:0] result
);

    // FIX: Single always block with complete conditional logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            result <= 8'b0;
        else if (sel)
            result <= data_a;
        else
            result <= data_b;
    end

endmodule
