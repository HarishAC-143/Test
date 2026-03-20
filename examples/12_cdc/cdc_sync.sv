// ============================================================================
// Multi-Stage Synchronizer (CDC)
// ============================================================================
// A parameterized multi-flop synchronizer for safely crossing single-bit
// signals between clock domains. The default 2 stages provide MTBF in the
// thousands of years at typical FPGA frequencies.
//
// For multi-bit signals, use an asynchronous FIFO or handshake protocol
// instead — never synchronize a multi-bit bus with a simple chain.
//
// Usage:
//   cdc_sync #(.STAGES(2)) u_sync (
//       .clk(dest_clk), .rst_n(dest_rst_n),
//       .async_in(signal_from_other_domain),
//       .sync_out(safe_signal)
//   );
// ============================================================================

module cdc_sync #(
    parameter int STAGES = 2
)(
    input  logic clk,
    input  logic rst_n,
    input  logic async_in,
    output logic sync_out
);

    (* async_reg = "true" *)
    logic [STAGES-1:0] sync_chain;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            sync_chain <= '0;
        else
            sync_chain <= {sync_chain[STAGES-2:0], async_in};
    end

    assign sync_out = sync_chain[STAGES-1];

endmodule


// ============================================================================
// Pulse Synchronizer
// ============================================================================
// Transfers a single-cycle pulse from one clock domain to another using
// a toggle-based approach. Works even when the destination clock is
// slower than the source clock.
// ============================================================================

module pulse_sync (
    // Source domain
    input  logic src_clk,
    input  logic src_rst_n,
    input  logic src_pulse,

    // Destination domain
    input  logic dst_clk,
    input  logic dst_rst_n,
    output logic dst_pulse
);

    logic toggle_src;
    logic toggle_dst, toggle_dst_prev;

    // Toggle on each pulse in source domain
    always_ff @(posedge src_clk or negedge src_rst_n) begin
        if (!src_rst_n)
            toggle_src <= 1'b0;
        else if (src_pulse)
            toggle_src <= ~toggle_src;
    end

    // Synchronize toggle into destination domain
    logic toggle_synced;
    cdc_sync #(.STAGES(2)) u_sync (
        .clk       (dst_clk),
        .rst_n     (dst_rst_n),
        .async_in  (toggle_src),
        .sync_out  (toggle_synced)
    );

    // Detect edges on the synchronized toggle
    always_ff @(posedge dst_clk or negedge dst_rst_n) begin
        if (!dst_rst_n)
            toggle_dst_prev <= 1'b0;
        else
            toggle_dst_prev <= toggle_synced;
    end

    assign dst_pulse = toggle_synced ^ toggle_dst_prev;

endmodule
