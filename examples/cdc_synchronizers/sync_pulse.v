//-----------------------------------------------------------------------------
// Synchronizer Library: Pulse Synchronizer
//
// Use Case:
//   Transferring single-cycle pulses across clock domains.
//   Works even when destination clock is slower than source clock
//   (a simple 2-FF sync would miss a 1-cycle pulse from a fast domain).
//
// How It Works:
//   1. Source domain toggles a level signal on each input pulse
//   2. Level signal is synchronized via 2-FF to destination domain
//   3. Destination domain detects the toggle (XOR with previous value)
//      and regenerates a pulse
//
// Characteristics:
//   - Latency: 2-3 destination clock cycles
//   - Throughput: 1 pulse per synchronization latency
//   - Limitation: Back-to-back pulses closer than sync latency are lost
//
// SpyGlass:
//   This pattern is recognized as a valid CDC synchronization scheme
//   when properly constrained.
//-----------------------------------------------------------------------------

module sync_pulse (
    input  wire clk_src,    // Source domain clock
    input  wire rst_src_n,  // Source domain reset
    input  wire clk_dst,    // Destination domain clock
    input  wire rst_dst_n,  // Destination domain reset
    input  wire pulse_in,   // Single-cycle pulse in source domain
    output wire pulse_out   // Regenerated pulse in destination domain
);

    //--- Source domain: toggle on each pulse ---
    reg toggle_src;

    always @(posedge clk_src or negedge rst_src_n) begin
        if (!rst_src_n)
            toggle_src <= 1'b0;
        else if (pulse_in)
            toggle_src <= ~toggle_src;
    end

    //--- Destination domain: synchronize the toggle level ---
    reg sync1, sync2, sync3;

    always @(posedge clk_dst or negedge rst_dst_n) begin
        if (!rst_dst_n) begin
            sync1 <= 1'b0;
            sync2 <= 1'b0;
            sync3 <= 1'b0;
        end else begin
            sync1 <= toggle_src;
            sync2 <= sync1;
            sync3 <= sync2;   // Extra stage for edge detection
        end
    end

    // Detect toggle → regenerate pulse
    assign pulse_out = sync2 ^ sync3;

endmodule


//-----------------------------------------------------------------------------
// Example: Using pulse synchronizer
//-----------------------------------------------------------------------------
module pulse_sync_example (
    input  wire clk_fast,     // 200 MHz
    input  wire clk_slow,     // 50 MHz
    input  wire rst_n,
    input  wire trigger,      // 1-cycle pulse in fast domain
    output wire event_out     // Regenerated pulse in slow domain
);

    sync_pulse u_pulse_sync (
        .clk_src   (clk_fast),
        .rst_src_n (rst_n),
        .clk_dst   (clk_slow),
        .rst_dst_n (rst_n),
        .pulse_in  (trigger),
        .pulse_out (event_out)
    );

endmodule
