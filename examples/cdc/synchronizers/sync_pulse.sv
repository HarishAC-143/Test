// =============================================================================
// sync_pulse -- Pulse Synchronizer (Toggle-Based)
//
// Transfers a single-cycle pulse from one clock domain to another.
// A simple 2-FF synchronizer would miss a pulse if the destination clock
// is slower than the source clock. This module converts the pulse to a
// level (toggle), synchronizes the level, then converts back to a pulse.
//
// Constraint: Source must not issue a new pulse until the previous one
// has been acknowledged (minimum spacing ~ 2 * Tdst + 2 * Tsrc cycles).
//
// Port Descriptions:
//   clk_src   -- source-domain clock
//   rst_src_n -- source-domain active-low reset
//   pulse_in  -- single-cycle pulse in source domain
//   clk_dst   -- destination-domain clock
//   rst_dst_n -- destination-domain active-low reset
//   pulse_out -- single-cycle pulse in destination domain
// =============================================================================

module sync_pulse (
    input  wire clk_src,
    input  wire rst_src_n,
    input  wire pulse_in,

    input  wire clk_dst,
    input  wire rst_dst_n,
    output wire pulse_out
);

    // Source domain: convert pulse to toggle
    reg toggle_src;

    always @(posedge clk_src or negedge rst_src_n) begin
        if (!rst_src_n)
            toggle_src <= 1'b0;
        else if (pulse_in)
            toggle_src <= ~toggle_src;
    end

    // Synchronize toggle into destination domain
    wire toggle_dst;

    sync_2ff #(.WIDTH(1)) u_sync (
        .clk   (clk_dst),
        .rst_n (rst_dst_n),
        .d     (toggle_src),
        .q     (toggle_dst)
    );

    // Destination domain: detect edges on toggle to regenerate pulse
    reg toggle_dst_d;

    always @(posedge clk_dst or negedge rst_dst_n) begin
        if (!rst_dst_n)
            toggle_dst_d <= 1'b0;
        else
            toggle_dst_d <= toggle_dst;
    end

    assign pulse_out = toggle_dst ^ toggle_dst_d;

endmodule
