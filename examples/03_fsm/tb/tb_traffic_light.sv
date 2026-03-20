// Testbench: Traffic Light Moore FSM

`timescale 1ns / 1ps

module tb_traffic_light;

    parameter CLK_PERIOD    = 10;
    parameter GREEN_TICKS   = 10;   // shortened for simulation
    parameter YELLOW_TICKS  = 5;
    parameter RED_TICKS     = 12;

    logic clk, rst_n, sensor;
    logic red, yellow, green;

    traffic_light_moore #(
        .GREEN_TICKS  (GREEN_TICKS),
        .YELLOW_TICKS (YELLOW_TICKS),
        .RED_TICKS    (RED_TICKS)
    ) u_dut (.*);

    initial clk = 1'b0;
    always #(CLK_PERIOD/2) clk = ~clk;

    task automatic wait_cycles(int n);
        repeat (n) @(posedge clk);
    endtask

    initial begin
        $display("=== TRAFFIC LIGHT Testbench ===");

        rst_n  = 1'b0;
        sensor = 1'b0;
        wait_cycles(3);
        rst_n = 1'b1;
        @(posedge clk);
        #1;

        // After reset: should be RED
        assert (red && !yellow && !green)
            else $error("After reset: expected RED");
        $display("  Reset -> RED  PASS");

        // Wait for red phase to end (RED_TICKS cycles)
        wait_cycles(RED_TICKS);
        #1;
        assert (!red && !yellow && green)
            else $error("After red: expected GREEN, got R=%0b Y=%0b G=%0b", red, yellow, green);
        $display("  RED -> GREEN  PASS");

        // Wait for green phase (no sensor)
        wait_cycles(GREEN_TICKS);
        #1;
        assert (!red && yellow && !green)
            else $error("After green: expected YELLOW");
        $display("  GREEN -> YELLOW  PASS");

        // Wait for yellow phase
        wait_cycles(YELLOW_TICKS);
        #1;
        assert (red && !yellow && !green)
            else $error("After yellow: expected RED");
        $display("  YELLOW -> RED  PASS");

        // Test sensor shortening green phase
        wait_cycles(RED_TICKS);
        #1;
        assert (green) else $error("Expected GREEN");

        sensor = 1'b1;
        wait_cycles(GREEN_TICKS / 2);
        #1;
        assert (yellow)
            else $error("Sensor: expected YELLOW after half green");
        $display("  Sensor shortens GREEN -> YELLOW  PASS");
        sensor = 1'b0;

        // Complete cycle
        wait_cycles(YELLOW_TICKS + 1);
        #1;
        assert (red) else $error("Expected RED after yellow");
        $display("  Full cycle complete  PASS");

        $display("=== TRAFFIC LIGHT All Tests Passed ===");
        $finish;
    end

    initial begin
        #100000;
        $error("Simulation timeout!");
        $finish;
    end

endmodule
