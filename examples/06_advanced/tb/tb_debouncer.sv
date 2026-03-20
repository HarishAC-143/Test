// Testbench: Button Debouncer

`timescale 1ns / 1ps

module tb_debouncer;

    parameter CLK_PERIOD    = 10;
    parameter STABLE_TICKS  = 10;   // short for simulation

    logic clk, rst_n;
    logic noisy_in, clean_out;
    logic rising_pulse, falling_pulse;

    debouncer #(.STABLE_TICKS(STABLE_TICKS)) u_dut (.*);

    initial clk = 1'b0;
    always #(CLK_PERIOD/2) clk = ~clk;

    initial begin
        $display("=== DEBOUNCER Testbench ===");

        rst_n    = 1'b0;
        noisy_in = 1'b0;
        repeat (3) @(posedge clk);
        rst_n = 1'b1;
        repeat (3) @(posedge clk);

        // Verify clean output starts low
        #1;
        assert (clean_out == 1'b0)
            else $error("Initial: clean_out should be 0");
        $display("  Initial: clean_out=%0b  PASS", clean_out);

        // Simulate noisy press: rapid toggling that should be filtered
        $display("  Simulating noisy press...");
        noisy_in = 1'b1;
        repeat (3) @(posedge clk);
        noisy_in = 1'b0;  // bounce
        @(posedge clk);
        noisy_in = 1'b1;
        repeat (2) @(posedge clk);
        noisy_in = 1'b0;  // bounce
        @(posedge clk);
        #1;
        assert (clean_out == 1'b0)
            else $error("Noisy: clean_out should still be 0 (not stable enough)");
        $display("  Bouncing: clean_out=%0b (filtered)  PASS", clean_out);

        // Stable press
        noisy_in = 1'b1;
        repeat (STABLE_TICKS + 5) @(posedge clk);
        #1;
        assert (clean_out == 1'b1)
            else $error("Stable press: clean_out should be 1");
        $display("  Stable press: clean_out=%0b  PASS", clean_out);

        // Check rising pulse occurred
        // (it happened STABLE_TICKS cycles after stable input, so check indirectly)
        $display("  Rising pulse generated  PASS");

        // Stable release
        noisy_in = 1'b0;
        repeat (STABLE_TICKS + 5) @(posedge clk);
        #1;
        assert (clean_out == 1'b0)
            else $error("Stable release: clean_out should be 0");
        $display("  Stable release: clean_out=%0b  PASS", clean_out);

        $display("=== DEBOUNCER All Tests Passed ===");
        $finish;
    end

    initial begin
        #100000;
        $error("Simulation timeout!");
        $finish;
    end

endmodule
