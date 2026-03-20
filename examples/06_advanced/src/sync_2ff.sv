// Two-Flop Synchronizer for Clock Domain Crossing (CDC)
// Mitigates metastability when transferring a single-bit signal
// from one clock domain to another.
// Synthesis attribute keeps tools from optimizing away the chain.

module sync_2ff #(
    parameter STAGES    = 2,
    parameter RESET_VAL = 1'b0
)(
    input  logic clk_dst,
    input  logic rst_dst_n,
    input  logic async_in,
    output logic sync_out
);

    (* async_reg = "true" *)
    logic [STAGES-1:0] sync_chain;

    always_ff @(posedge clk_dst or negedge rst_dst_n) begin
        if (!rst_dst_n)
            sync_chain <= {STAGES{RESET_VAL}};
        else
            sync_chain <= {sync_chain[STAGES-2:0], async_in};
    end

    assign sync_out = sync_chain[STAGES-1];

endmodule
