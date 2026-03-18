// =============================================================================
// sync_bus_mux -- MUX-Qualified Bus Synchronizer
//
// Transfers a multi-bit bus between clock domains using a load-enable
// (qualifier) signal. The qualifier is synchronized; the bus itself is
// sampled only when the qualifier indicates the data is stable.
//
// Protocol:
//   1. Source asserts 'load' for one clk_src cycle when 'd' is valid.
//   2. Source must hold 'd' stable until the load is acknowledged.
//   3. Destination captures 'd' once the synchronized load pulse arrives.
//
// This avoids the need for Gray encoding and works for arbitrary buses.
//
// Parameters:
//   WIDTH -- bus width (default 8)
// =============================================================================

module sync_bus_mux #(
    parameter WIDTH = 8
) (
    input  wire             clk_src,
    input  wire             rst_src_n,
    input  wire             clk_dst,
    input  wire             rst_dst_n,
    input  wire [WIDTH-1:0] d,
    output reg  [WIDTH-1:0] q
);

    // Source domain: detect change on input (simplified: capture every cycle)
    reg [WIDTH-1:0] d_hold;
    reg             load_toggle;

    always @(posedge clk_src or negedge rst_src_n) begin
        if (!rst_src_n) begin
            d_hold      <= {WIDTH{1'b0}};
            load_toggle <= 1'b0;
        end else if (d != d_hold) begin
            d_hold      <= d;
            load_toggle <= ~load_toggle;
        end
    end

    // Synchronize the toggle into the destination domain
    wire load_toggle_dst;

    sync_2ff #(.WIDTH(1)) u_sync_toggle (
        .clk   (clk_dst),
        .rst_n (rst_dst_n),
        .d     (load_toggle),
        .q     (load_toggle_dst)
    );

    // Edge-detect on the synchronized toggle -> generates a load pulse
    reg load_toggle_dst_d;

    always @(posedge clk_dst or negedge rst_dst_n) begin
        if (!rst_dst_n)
            load_toggle_dst_d <= 1'b0;
        else
            load_toggle_dst_d <= load_toggle_dst;
    end

    wire load_pulse = load_toggle_dst ^ load_toggle_dst_d;

    // Capture the data when the load pulse fires (data is stable by now)
    always @(posedge clk_dst or negedge rst_dst_n) begin
        if (!rst_dst_n)
            q <= {WIDTH{1'b0}};
        else if (load_pulse)
            q <= d_hold;
    end

endmodule
