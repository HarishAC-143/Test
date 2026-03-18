// =============================================================================
// sync_2ff -- Parameterized 2-Flip-Flop Synchronizer
//
// The most basic CDC synchronizer. Reduces metastability probability to
// an acceptably low level (MTBF typically > 100 years at GHz frequencies).
//
// Usage:
//   - Single-bit level signals (not pulses)
//   - Multi-bit signals ONLY if they are Gray-encoded (at most 1 bit
//     changes per source-clock cycle)
//
// Parameters:
//   WIDTH  -- number of bits (default 1)
//
// Synthesis attributes:
//   The (* async_reg = "true" *) attribute tells the synthesis tool to
//   place the two flops close together to minimize the wire delay between
//   them, which improves MTBF.
// =============================================================================

module sync_2ff #(
    parameter WIDTH = 1
) (
    input  wire             clk,
    input  wire             rst_n,
    input  wire [WIDTH-1:0] d,
    output wire [WIDTH-1:0] q
);

    (* async_reg = "true" *) reg [WIDTH-1:0] sync_stage1;
    (* async_reg = "true" *) reg [WIDTH-1:0] sync_stage2;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sync_stage1 <= {WIDTH{1'b0}};
            sync_stage2 <= {WIDTH{1'b0}};
        end else begin
            sync_stage1 <= d;
            sync_stage2 <= sync_stage1;
        end
    end

    assign q = sync_stage2;

endmodule
