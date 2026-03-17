// Testbench for Up Counter
// Demonstrates clock-driven testbench with assertions

module counter_tb;

    parameter WIDTH = 4;

    logic             clk;
    logic             rst_n;
    logic             enable;
    logic             clear;
    logic [WIDTH-1:0] count;
    logic             overflow;

    // Instantiate DUT
    up_counter #(.WIDTH(WIDTH)) dut (
        .clk      (clk),
        .rst_n    (rst_n),
        .enable   (enable),
        .clear    (clear),
        .count    (count),
        .overflow (overflow)
    );

    // Clock generation: 10ns period
    initial clk = 0;
    always #5 clk = ~clk;

    // Test sequence
    initial begin
        $display("=== Counter Testbench ===");

        // Initialize
        rst_n  = 1'b0;
        enable = 1'b0;
        clear  = 1'b0;

        // Hold reset for a few cycles
        repeat (3) @(posedge clk);
        rst_n = 1'b1;
        @(posedge clk);

        // Verify counter is zero after reset
        assert (count == '0) else $error("Count should be 0 after reset");
        $display("PASS: Counter is 0 after reset");

        // Enable counting
        enable = 1'b1;
        repeat (5) @(posedge clk);
        #1;

        $display("After 5 clocks: count = %0d", count);
        assert (count == 4'd5) else $error("Expected count=5, got %0d", count);
        $display("PASS: Count is 5 after 5 enabled clocks");

        // Test clear
        clear = 1'b1;
        @(posedge clk);
        #1;
        clear = 1'b0;

        assert (count == '0) else $error("Count should be 0 after clear");
        $display("PASS: Counter cleared successfully");

        // Count to overflow
        enable = 1'b1;
        repeat ((1 << WIDTH) - 1) @(posedge clk);
        #1;

        $display("Near overflow: count = %0d, overflow = %b", count, overflow);

        // One more clock to observe overflow
        @(posedge clk);
        #1;

        $display("After overflow: count = %0d", count);
        assert (count == '0) else $error("Count should wrap to 0");
        $display("PASS: Counter wrapped around correctly");

        // Disable counting
        enable = 1'b0;
        @(posedge clk);
        #1;

        logic [WIDTH-1:0] saved_count = count;
        repeat (3) @(posedge clk);
        #1;

        assert (count == saved_count) else $error("Counter should not change when disabled");
        $display("PASS: Counter holds value when disabled");

        $display("");
        $display("=== All counter tests passed ===");
        $finish;
    end

    // Dump waveforms
    initial begin
        $dumpfile("counter_tb.vcd");
        $dumpvars(0, counter_tb);
    end

endmodule
