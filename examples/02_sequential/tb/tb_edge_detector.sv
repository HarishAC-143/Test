// Testbench: Edge Detector

`timescale 1ns / 1ps

module tb_edge_detector;

    parameter CLK_PERIOD = 10;

    logic clk, rst_n, signal_in;
    logic rising_edge, falling_edge, any_edge;

    edge_detector u_dut (.*);

    initial clk = 1'b0;
    always #(CLK_PERIOD/2) clk = ~clk;

    initial begin
        $display("=== EDGE DETECTOR Testbench ===");

        rst_n     = 1'b0;
        signal_in = 1'b0;
        repeat (3) @(posedge clk);
        rst_n = 1'b1;
        @(posedge clk);

        // Steady low — no edges
        #1;
        assert (rising_edge == 0 && falling_edge == 0 && any_edge == 0)
            else $error("Steady low: no edges expected");
        $display("  Steady low: rise=%0b fall=%0b any=%0b  PASS",
                 rising_edge, falling_edge, any_edge);

        // Rising edge
        signal_in = 1'b1;
        @(posedge clk);
        #1;
        assert (rising_edge == 1 && falling_edge == 0 && any_edge == 1)
            else $error("Rising edge not detected");
        $display("  Rising:     rise=%0b fall=%0b any=%0b  PASS",
                 rising_edge, falling_edge, any_edge);

        // Steady high — single-cycle pulse should end
        @(posedge clk);
        #1;
        assert (rising_edge == 0 && falling_edge == 0 && any_edge == 0)
            else $error("Steady high: no edges expected");
        $display("  Steady hi:  rise=%0b fall=%0b any=%0b  PASS",
                 rising_edge, falling_edge, any_edge);

        // Falling edge
        signal_in = 1'b0;
        @(posedge clk);
        #1;
        assert (rising_edge == 0 && falling_edge == 1 && any_edge == 1)
            else $error("Falling edge not detected");
        $display("  Falling:    rise=%0b fall=%0b any=%0b  PASS",
                 rising_edge, falling_edge, any_edge);

        // Toggle every cycle
        repeat (4) begin
            signal_in = ~signal_in;
            @(posedge clk);
            #1;
            assert (any_edge == 1)
                else $error("Toggle: any_edge should be 1");
        end
        $display("  Toggle:     continuous edges detected  PASS");

        $display("=== EDGE DETECTOR All Tests Passed ===");
        $finish;
    end

    initial begin
        #10000;
        $error("Simulation timeout!");
        $finish;
    end

endmodule
