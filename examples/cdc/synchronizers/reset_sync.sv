// =============================================================================
// reset_sync -- Asynchronous Assert, Synchronous Deassert Reset Synchronizer
//
// When a reset originates in a different clock domain, it must be
// synchronized before use. This module implements the standard pattern:
//
//   - Assert (activate) immediately on the asynchronous reset input
//   - Deassert (release) synchronously to the destination clock
//
// This ensures that:
//   1. Reset is applied without waiting for the clock (needed for power-up).
//   2. Reset removal does not violate recovery/removal timing of destination
//      flip-flops.
//
// NUM_STAGES controls the depth of the synchronizer chain (minimum 2).
// =============================================================================

module reset_sync #(
    parameter NUM_STAGES = 2
) (
    input  wire clk,
    input  wire rst_in_n,      // asynchronous reset input (active low)
    output wire rst_out_n      // synchronized reset output (active low)
);

    (* async_reg = "true" *) reg [NUM_STAGES-1:0] sync_chain;

    always @(posedge clk or negedge rst_in_n) begin
        if (!rst_in_n)
            sync_chain <= {NUM_STAGES{1'b0}};       // assert immediately
        else
            sync_chain <= {sync_chain[NUM_STAGES-2:0], 1'b1};  // shift in '1'
    end

    assign rst_out_n = sync_chain[NUM_STAGES-1];    // deasserts synchronously

endmodule
