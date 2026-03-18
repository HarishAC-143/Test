//-----------------------------------------------------------------------------
// Synchronizer Library: 2-FF Synchronizer (Parameterized)
//
// Use Case:
//   Single-bit control signals crossing clock domains.
//
// Characteristics:
//   - Latency: 2 destination-clock cycles (configurable via NUM_STAGES)
//   - Throughput: 1 bit per crossing
//   - MTBF: Exponentially improves with each additional stage
//   - Constraints: Source signal must be stable for at least 1 full
//     destination clock period (otherwise use pulse synchronizer)
//
// Synthesis Attributes:
//   - async_reg: Tells synthesis to place flip-flops close together
//   - dont_touch: Prevents optimization from removing sync stages
//-----------------------------------------------------------------------------

module sync_2ff #(
    parameter NUM_STAGES  = 2,     // Minimum 2; use 3 for very high freq
    parameter RESET_VALUE = 1'b0   // Value on reset
) (
    input  wire clk,       // Destination clock
    input  wire rst_n,     // Destination async reset
    input  wire d,         // Async input from source domain
    output wire q          // Synchronized output
);

    (* async_reg = "true", dont_touch = "true" *)
    reg [NUM_STAGES-1:0] sync_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            sync_reg <= {NUM_STAGES{RESET_VALUE}};
        else
            sync_reg <= {sync_reg[NUM_STAGES-2:0], d};
    end

    assign q = sync_reg[NUM_STAGES-1];

endmodule
