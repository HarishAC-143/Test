//-----------------------------------------------------------------------------
// Example: Blocking vs. Non-Blocking Assignment Issues
//
// SpyGlass Rules Triggered:
//   W_391          - Blocking assignment in sequential (clocked) always block
//   STARC-2.3.1.1  - Improper use of blocking assignment
//   W_456          - Non-blocking assignment in combinational block
//
// The Verilog simulation semantics for blocking (=) and non-blocking (<=)
// assignments differ. Using the wrong type leads to simulation/synthesis
// mismatches.
//
// Rules of thumb:
//   - Sequential logic (posedge/negedge): use NON-BLOCKING (<=)
//   - Combinational logic (always @*):    use BLOCKING (=)
//-----------------------------------------------------------------------------

module blocking_nonblocking_bad (
    input  wire       clk,
    input  wire       rst_n,
    input  wire [7:0] data_in,
    output reg  [7:0] stage1,
    output reg  [7:0] stage2,
    output reg  [7:0] stage3,
    output reg  [7:0] combo_out,
    input  wire [7:0] combo_a,
    input  wire [7:0] combo_b
);

    // BUG: Blocking assignments in sequential block
    // In simulation, stage2 gets the NEW value of stage1 (same delta cycle)
    // In synthesis, both stage1 and stage2 are registered — stage2 gets the OLD value
    // Result: simulation and synthesis produce different behavior
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            stage1 = 8'b0;           // W_391: should be <=
            stage2 = 8'b0;           // W_391: should be <=
            stage3 = 8'b0;           // W_391: should be <=
        end else begin
            stage1 = data_in;        // stage1 gets data_in
            stage2 = stage1;         // stage2 gets NEW stage1 (= data_in) in sim
            stage3 = stage2;         // stage3 gets NEW stage2 (= data_in) in sim
            // Simulation: all three get data_in in the same cycle
            // Synthesis:  3-stage pipeline (correct behavior)
        end
    end

    // BUG: Non-blocking assignment in combinational block
    // Can cause simulation issues with ordering
    always @(*) begin
        combo_out <= combo_a + combo_b;  // W_456: should be =
    end

endmodule


module blocking_nonblocking_good (
    input  wire       clk,
    input  wire       rst_n,
    input  wire [7:0] data_in,
    output reg  [7:0] stage1,
    output reg  [7:0] stage2,
    output reg  [7:0] stage3,
    output reg  [7:0] combo_out,
    input  wire [7:0] combo_a,
    input  wire [7:0] combo_b
);

    // FIX: Non-blocking assignments in sequential block
    // Simulation now matches synthesis: 3-stage pipeline
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            stage1 <= 8'b0;
            stage2 <= 8'b0;
            stage3 <= 8'b0;
        end else begin
            stage1 <= data_in;       // stage1 registers data_in
            stage2 <= stage1;        // stage2 registers OLD stage1
            stage3 <= stage2;        // stage3 registers OLD stage2
        end
    end

    // FIX: Blocking assignment in combinational block
    always @(*) begin
        combo_out = combo_a + combo_b;
    end

endmodule
