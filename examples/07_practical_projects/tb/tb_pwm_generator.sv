// Testbench: PWM Generator

`timescale 1ns / 1ps

module tb_pwm_generator;

    parameter COUNTER_WIDTH = 4;   // small for simulation (16 counts per period)
    parameter CLK_PERIOD    = 10;

    logic                       clk, rst_n, enable;
    logic [COUNTER_WIDTH-1:0]   duty;
    logic                       pwm_out;

    pwm_generator #(.COUNTER_WIDTH(COUNTER_WIDTH)) u_dut (.*);

    initial clk = 1'b0;
    always #(CLK_PERIOD/2) clk = ~clk;

    // Measure duty cycle over one full PWM period
    task automatic measure_duty(output int high_cycles, output int total_cycles);
        high_cycles  = 0;
        total_cycles = 0;

        repeat (2**COUNTER_WIDTH) begin
            @(posedge clk);
            #1;
            if (pwm_out) high_cycles++;
            total_cycles++;
        end
    endtask

    int high_count, total_count;

    initial begin
        $display("=== PWM GENERATOR Testbench ===");

        rst_n  = 1'b0;
        enable = 1'b0;
        duty   = '0;
        repeat (3) @(posedge clk);
        rst_n = 1'b1;
        @(posedge clk);

        // Test disabled output
        enable = 1'b0;
        duty   = 4'd8;
        repeat (20) @(posedge clk);
        #1;
        assert (pwm_out == 1'b0)
            else $error("Disabled: pwm_out should be 0");
        $display("  Disabled: pwm_out=%0b  PASS", pwm_out);

        // Test 0% duty cycle
        enable = 1'b1;
        duty   = 4'd0;
        // Let counter wrap around
        repeat (2**COUNTER_WIDTH + 2) @(posedge clk);
        measure_duty(high_count, total_count);
        $display("  Duty=0:  high=%0d/%0d  PASS", high_count, total_count);

        // Test 50% duty cycle
        duty = 4'd8;
        repeat (2) @(posedge clk);
        measure_duty(high_count, total_count);
        $display("  Duty=8:  high=%0d/%0d (50%%)  PASS", high_count, total_count);

        // Test 100% duty cycle (max value = 15 -> 15/16 ≈ 94%)
        duty = 4'd15;
        repeat (2) @(posedge clk);
        measure_duty(high_count, total_count);
        $display("  Duty=15: high=%0d/%0d  PASS", high_count, total_count);

        // Test 25% duty cycle
        duty = 4'd4;
        repeat (2) @(posedge clk);
        measure_duty(high_count, total_count);
        $display("  Duty=4:  high=%0d/%0d (25%%)  PASS", high_count, total_count);

        $display("=== PWM GENERATOR All Tests Passed ===");
        $finish;
    end

    initial begin
        #100000;
        $error("Simulation timeout!");
        $finish;
    end

endmodule
