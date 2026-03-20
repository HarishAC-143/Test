// Pulse synchronizer — transfers a single-cycle pulse from one clock domain to another.
//
// Technique: Convert pulse to toggle in source domain, synchronize the toggle,
// then detect edge in destination domain to regenerate the pulse.
//
// Limitation: Source pulses must be spaced far enough apart for the toggle to
// propagate (at least 2 destination clock cycles between pulses).

module pulse_sync (
    // Source domain
    input  logic clk_src,
    input  logic rst_src_n,
    input  logic pulse_in,

    // Destination domain
    input  logic clk_dst,
    input  logic rst_dst_n,
    output logic pulse_out
);

    // Source domain: convert pulse to toggle
    logic toggle_src;

    always_ff @(posedge clk_src or negedge rst_src_n) begin
        if (!rst_src_n)
            toggle_src <= 1'b0;
        else if (pulse_in)
            toggle_src <= ~toggle_src;
    end

    // Destination domain: synchronize the toggle
    logic toggle_dst;

    two_ff_sync #(.STAGES(2), .INIT_VAL(1'b0)) u_sync (
        .clk_dst   (clk_dst),
        .rst_dst_n (rst_dst_n),
        .data_in   (toggle_src),
        .data_out  (toggle_dst)
    );

    // Destination domain: detect edge to regenerate pulse
    logic toggle_dst_d;

    always_ff @(posedge clk_dst or negedge rst_dst_n) begin
        if (!rst_dst_n)
            toggle_dst_d <= 1'b0;
        else
            toggle_dst_d <= toggle_dst;
    end

    assign pulse_out = toggle_dst ^ toggle_dst_d;

endmodule
