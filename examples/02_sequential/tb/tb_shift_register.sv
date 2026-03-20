// Testbench: Universal Shift Register

`timescale 1ns / 1ps

module tb_shift_register;

    parameter WIDTH = 8;
    parameter CLK_PERIOD = 10;

    logic             clk, rst_n;
    logic [1:0]       mode;
    logic             serial_left_in, serial_right_in;
    logic [WIDTH-1:0] parallel_in, parallel_out;
    logic             serial_left_out, serial_right_out;

    shift_register #(.WIDTH(WIDTH)) u_dut (.*);

    initial clk = 1'b0;
    always #(CLK_PERIOD/2) clk = ~clk;

    initial begin
        $display("=== SHIFT REGISTER Testbench ===");

        // Reset
        rst_n = 1'b0;
        mode = 2'b00;
        serial_left_in = 1'b0;
        serial_right_in = 1'b0;
        parallel_in = '0;
        repeat (3) @(posedge clk);
        rst_n = 1'b1;
        @(posedge clk);
        #1;
        assert (parallel_out == '0) else $error("Reset failed");
        $display("  Reset: out=%08b  PASS", parallel_out);

        // Parallel load
        mode = 2'b11;
        parallel_in = 8'b1010_0101;
        @(posedge clk);
        #1;
        assert (parallel_out == 8'b1010_0101)
            else $error("Load: expected 10100101, got %08b", parallel_out);
        $display("  Load:  out=%08b  PASS", parallel_out);

        // Shift left
        mode = 2'b10;
        serial_right_in = 1'b1;
        @(posedge clk);
        #1;
        assert (parallel_out == 8'b0100_1011)
            else $error("Shift left: expected 01001011, got %08b", parallel_out);
        $display("  SHL:   out=%08b  PASS", parallel_out);

        // Shift right
        mode = 2'b01;
        serial_left_in = 1'b0;
        @(posedge clk);
        #1;
        assert (parallel_out == 8'b0010_0101)
            else $error("Shift right: expected 00100101, got %08b", parallel_out);
        $display("  SHR:   out=%08b  PASS", parallel_out);

        // Hold
        mode = 2'b00;
        repeat (3) @(posedge clk);
        #1;
        assert (parallel_out == 8'b0010_0101)
            else $error("Hold failed: value changed");
        $display("  Hold:  out=%08b  PASS", parallel_out);

        // Serial output check
        mode = 2'b11;
        parallel_in = 8'b1000_0001;
        @(posedge clk);
        #1;
        assert (serial_left_out == 1'b1 && serial_right_out == 1'b1)
            else $error("Serial outputs wrong");
        $display("  Serial: left=%0b right=%0b  PASS", serial_left_out, serial_right_out);

        $display("=== SHIFT REGISTER All Tests Passed ===");
        $finish;
    end

    initial begin
        #10000;
        $error("Simulation timeout!");
        $finish;
    end

endmodule
