// Configurable clock and reset generator — useful for multi-clock testbenches.

module clk_rst_generator #(
    parameter int CLK_PERIOD_NS   = 10,    // clock period in ns
    parameter int RST_CYCLES      = 5,     // reset assertion duration in clock cycles
    parameter bit ACTIVE_LOW_RST  = 1      // 1 = active-low reset, 0 = active-high
)(
    output logic clk,
    output logic rst
);

    // Clock generation
    initial clk = 1'b0;
    always #(CLK_PERIOD_NS / 2) clk = ~clk;

    // Reset generation
    initial begin
        rst = ACTIVE_LOW_RST ? 1'b0 : 1'b1;  // assert
        repeat (RST_CYCLES) @(posedge clk);
        rst = ACTIVE_LOW_RST ? 1'b1 : 1'b0;  // deassert
    end

endmodule
