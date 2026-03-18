// =============================================================================
// SpyGlass Lint Fix: Blocking in Sequential Logic (W71) — Corrected
// =============================================================================
//
// All sequential (clocked) always blocks now use non-blocking
// assignments (<=) exclusively, ensuring correct pipeline behavior
// and eliminating simulation-synthesis mismatches.
// =============================================================================

module pipeline_fixed (
    input        clk,
    input        rst_n,
    input  [7:0] data_in,
    output [7:0] data_out
);

    reg [7:0] stage1, stage2, stage3;

    // Non-blocking assignments: each stage samples the PREVIOUS
    // value of the preceding stage (as of the last clock edge).
    // The pipeline correctly delays data by 3 cycles.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            stage1 <= 8'h0;
            stage2 <= 8'h0;
            stage3 <= 8'h0;
        end else begin
            stage1 <= data_in;
            stage2 <= stage1;  // Samples old stage1
            stage3 <= stage2;  // Samples old stage2
        end
    end

    assign data_out = stage3;

endmodule


module mixed_assignment_fixed (
    input        clk,
    input        rst_n,
    input  [7:0] a, b,
    output reg [7:0] sum,
    output reg       overflow
);

    // Use non-blocking for all sequential assignments.
    // Intermediate combinational values should be computed
    // in a separate combinational block or as wires.
    wire [8:0] full_sum = {1'b0, a} + {1'b0, b};

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sum      <= 8'h0;
            overflow <= 1'b0;
        end else begin
            sum      <= full_sum[7:0];
            overflow <= full_sum[8];
        end
    end

endmodule
