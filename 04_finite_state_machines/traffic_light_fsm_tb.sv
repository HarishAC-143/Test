// Testbench for traffic light FSM.

module traffic_light_fsm_tb;

    localparam int CLK_PERIOD   = 10;
    localparam int RED_TICKS    = 10;
    localparam int GREEN_TICKS  = 8;
    localparam int YELLOW_TICKS = 4;

    logic clk, rst_n, sensor;
    logic red, yellow, green;

    traffic_light_fsm #(
        .RED_TICKS    (RED_TICKS),
        .GREEN_TICKS  (GREEN_TICKS),
        .YELLOW_TICKS (YELLOW_TICKS)
    ) dut (.*);

    initial clk = 1'b0;
    always #(CLK_PERIOD/2) clk = ~clk;

    int error_count = 0;

    task automatic check_state(input string expected_state);
        string actual;
        if (red && !yellow && !green)
            actual = "RED";
        else if (!red && !yellow && green)
            actual = "GREEN";
        else if (!red && yellow && !green)
            actual = "YELLOW";
        else
            actual = "INVALID";

        if (actual != expected_state) begin
            $display("FAIL [%0t]: expected %s, got %s", $time, expected_state, actual);
            error_count++;
        end
    endtask

    initial begin
        $display("=== Traffic Light FSM Testbench ===");

        rst_n  = 1'b0;
        sensor = 1'b0;
        repeat (3) @(posedge clk);
        rst_n = 1'b1;
        @(posedge clk);
        check_state("RED");

        // Wait through RED phase
        repeat (RED_TICKS - 1) @(posedge clk);
        @(posedge clk);
        check_state("GREEN");

        // Wait through GREEN phase
        repeat (GREEN_TICKS - 1) @(posedge clk);
        @(posedge clk);
        check_state("YELLOW");

        // Wait through YELLOW phase
        repeat (YELLOW_TICKS - 1) @(posedge clk);
        @(posedge clk);
        check_state("RED");

        // Test sensor shortening green
        repeat (RED_TICKS) @(posedge clk);
        // Now in GREEN
        repeat (GREEN_TICKS / 2) @(posedge clk);
        sensor = 1'b1;
        @(posedge clk);
        sensor = 1'b0;
        @(posedge clk);
        check_state("YELLOW");

        $display("\nSensor-triggered transition verified.");

        if (error_count == 0)
            $display("*** ALL TESTS PASSED ***");
        else
            $display("*** %0d TESTS FAILED ***", error_count);

        $finish;
    end

    initial begin
        $dumpfile("traffic_light.vcd");
        $dumpvars(0, traffic_light_fsm_tb);
    end

endmodule
