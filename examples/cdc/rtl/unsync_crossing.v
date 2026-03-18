// =============================================================================
// SpyGlass CDC Example: Unsynchronized Single-Bit Crossing (Ac_cdc01)
// =============================================================================
//
// SpyGlass Rule: Ac_cdc01
// Severity:      Error
// Category:      Clock Domain Crossing
//
// A single-bit signal generated in one clock domain is directly sampled
// by a flip-flop in another asynchronous clock domain without any
// synchronization. This can cause metastability in the destination
// flip-flop, leading to unpredictable values and potential system failure.
//
// Run with: current_goal cdc/cdc_verify
// =============================================================================

module unsync_crossing (
    input  clk_a,
    input  rst_a_n,
    input  clk_b,
    input  rst_b_n,
    input  data_in,
    output reg data_out
);

    reg data_reg_a;

    // Source domain: register the signal in clk_a domain
    always @(posedge clk_a or negedge rst_a_n) begin
        if (!rst_a_n)
            data_reg_a <= 1'b0;
        else
            data_reg_a <= data_in;
    end

    // Ac_cdc01 VIOLATION:
    // data_reg_a (clk_a domain) is directly sampled by a clk_b flip-flop.
    // If data_reg_a transitions near a clk_b rising edge, the destination
    // flip-flop may enter a metastable state, producing an unpredictable
    // output that could propagate through the design.
    always @(posedge clk_b or negedge rst_b_n) begin
        if (!rst_b_n)
            data_out <= 1'b0;
        else
            data_out <= data_reg_a;  // UNSYNCHRONIZED CROSSING!
    end

endmodule
