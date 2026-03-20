// Edge Detector
// Produces single-cycle pulses for rising, falling, and any-edge transitions.
// Commonly used for button/signal edge detection in FPGA designs.

module edge_detector (
    input  logic clk,
    input  logic rst_n,
    input  logic signal_in,
    output logic rising_edge,
    output logic falling_edge,
    output logic any_edge
);

    logic signal_d;  // delayed version

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            signal_d <= 1'b0;
        else
            signal_d <= signal_in;
    end

    assign rising_edge  = signal_in & ~signal_d;
    assign falling_edge = ~signal_in & signal_d;
    assign any_edge     = signal_in ^ signal_d;

endmodule
