// Edge detector — detects rising, falling, or any edge on the input signal.
// The input is assumed to be synchronous to clk.

module edge_detector (
    input  logic clk,
    input  logic rst_n,
    input  logic signal_in,
    output logic rising_edge,
    output logic falling_edge,
    output logic any_edge
);

    logic signal_delayed;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            signal_delayed <= 1'b0;
        else
            signal_delayed <= signal_in;
    end

    assign rising_edge  =  signal_in & ~signal_delayed;
    assign falling_edge = ~signal_in &  signal_delayed;
    assign any_edge     =  signal_in ^  signal_delayed;

endmodule
