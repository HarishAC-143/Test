// =============================================================================
// Pipelined Multiplier — 4-Stage Pipeline
// Demonstrates pipeline register insertion for high-throughput multiplication.
// Breaks the critical path into manageable segments for higher clock frequency.
// =============================================================================

module pipelined_multiplier #(
    parameter WIDTH = 16,
    parameter RESULT_WIDTH = 2 * WIDTH,
    parameter NUM_STAGES = 4
) (
    input  logic                     clk,
    input  logic                     rst_n,
    input  logic                     valid_in,
    input  logic [WIDTH-1:0]         a,
    input  logic [WIDTH-1:0]         b,
    output logic [RESULT_WIDTH-1:0]  result,
    output logic                     valid_out
);

    localparam QUARTER = WIDTH / NUM_STAGES;

    // Pipeline registers for partial products
    logic [RESULT_WIDTH-1:0] partial [NUM_STAGES+1];
    logic [NUM_STAGES:0]     valid_pipe;

    // Store operand B through the pipeline
    logic [WIDTH-1:0] b_pipe [NUM_STAGES];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_pipe <= '0;
            for (int i = 0; i <= NUM_STAGES; i++)
                partial[i] <= '0;
            for (int i = 0; i < NUM_STAGES; i++)
                b_pipe[i] <= '0;
        end else begin
            // Stage 0: Initialize
            valid_pipe[0] <= valid_in;
            partial[0]    <= '0;
            b_pipe[0]     <= b;

            // Stage 1..N: Accumulate partial products
            for (int s = 0; s < NUM_STAGES; s++) begin
                valid_pipe[s+1] <= valid_pipe[s];

                // Multiply a partial slice of A by full B and accumulate
                partial[s+1] <= partial[s] +
                    ((RESULT_WIDTH'(a[QUARTER*s +: QUARTER]) * RESULT_WIDTH'(b_pipe[s])) << (QUARTER * s));

                if (s < NUM_STAGES - 1)
                    b_pipe[s+1] <= b_pipe[s];
            end
        end
    end

    assign result    = partial[NUM_STAGES];
    assign valid_out = valid_pipe[NUM_STAGES];

endmodule
