// Two-flop synchronizer for single-bit clock domain crossing.
//
// Synthesis attributes tell the tools to:
// - Not optimize away the registers
// - Place them close together to minimize routing delay
// - Apply proper timing constraints

module two_ff_sync #(
    parameter int STAGES   = 2,     // minimum 2; increase for higher MTBF
    parameter     INIT_VAL = 1'b0   // reset value
)(
    input  logic clk_dst,    // destination domain clock
    input  logic rst_dst_n,  // destination domain reset
    input  logic data_in,    // from source domain (asynchronous to clk_dst)
    output logic data_out    // synchronized to clk_dst
);

    (* async_reg = "true" *)
    logic [STAGES-1:0] sync_chain;

    always_ff @(posedge clk_dst or negedge rst_dst_n) begin
        if (!rst_dst_n)
            sync_chain <= {STAGES{INIT_VAL}};
        else
            sync_chain <= {sync_chain[STAGES-2:0], data_in};
    end

    assign data_out = sync_chain[STAGES-1];

endmodule
