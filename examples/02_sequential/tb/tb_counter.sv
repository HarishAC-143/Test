// Testbench: Configurable Up/Down Counter

`timescale 1ns / 1ps

module tb_counter;

    parameter WIDTH = 4;
    parameter MAX_COUNT = 15;
    parameter CLK_PERIOD = 10;

    logic             clk, rst_n, enable, up_down, load;
    logic [WIDTH-1:0] load_val, count;
    logic             overflow, underflow;

    counter #(.WIDTH(WIDTH), .MAX_COUNT(MAX_COUNT)) u_dut (.*);

    initial clk = 1'b0;
    always #(CLK_PERIOD/2) clk = ~clk;

    initial begin
        $display("=== COUNTER Testbench ===");

        // Reset
        rst_n   = 1'b0;
        enable  = 1'b0;
        up_down = 1'b1;
        load    = 1'b0;
        load_val = '0;
        repeat (3) @(posedge clk);
        rst_n = 1'b1;
        @(posedge clk);

        assert (count == '0) else $error("After reset: count should be 0");
        $display("  Reset: count=%0d  PASS", count);

        // Count up
        enable = 1'b1;
        up_down = 1'b1;
        repeat (5) @(posedge clk);
        #1;
        assert (count == 4'd5) else $error("Count up: expected 5, got %0d", count);
        $display("  Count up 5 cycles: count=%0d  PASS", count);

        // Load
        load = 1'b1;
        load_val = 4'd13;
        @(posedge clk);
        load = 1'b0;
        #1;
        assert (count == 4'd13) else $error("Load: expected 13, got %0d", count);
        $display("  Load 13: count=%0d  PASS", count);

        // Count up to overflow
        repeat (2) @(posedge clk);
        #1;
        assert (count == 4'd15) else $error("At max: expected 15, got %0d", count);
        @(posedge clk);
        #1;
        assert (count == 4'd0 && overflow == 1'b1)
            else $error("Overflow: expected count=0 ovf=1, got count=%0d ovf=%0b", count, overflow);
        $display("  Overflow: count=%0d overflow=%0b  PASS", count, overflow);

        // Count down
        up_down = 1'b0;
        @(posedge clk);
        #1;
        assert (underflow == 1'b1)
            else $error("Underflow: expected underflow=1, got %0b", underflow);
        $display("  Underflow: count=%0d underflow=%0b  PASS", count, underflow);

        // Disable counting
        enable = 1'b0;
        logic [WIDTH-1:0] saved_count;
        saved_count = count;
        repeat (3) @(posedge clk);
        #1;
        assert (count == saved_count)
            else $error("Disabled: count should not change, expected %0d, got %0d", saved_count, count);
        $display("  Disabled: count=%0d (unchanged)  PASS", count);

        $display("=== COUNTER All Tests Passed ===");
        $finish;
    end

    // Timeout
    initial begin
        #10000;
        $error("Simulation timeout!");
        $finish;
    end

endmodule
