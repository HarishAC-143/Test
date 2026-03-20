// Testbench: Pipelined MAC Unit

`timescale 1ns / 1ps

module tb_pipeline_mac;

    parameter A_WIDTH   = 8;
    parameter B_WIDTH   = 8;
    parameter ACC_WIDTH  = 24;
    parameter CLK_PERIOD = 10;

    logic                    clk, rst_n;
    logic                    clear_acc, valid_in;
    logic [A_WIDTH-1:0]      a;
    logic [B_WIDTH-1:0]      b;
    logic [ACC_WIDTH-1:0]    acc_out;
    logic                    valid_out;

    pipeline_mac #(
        .A_WIDTH(A_WIDTH),
        .B_WIDTH(B_WIDTH),
        .ACC_WIDTH(ACC_WIDTH)
    ) u_dut (.*);

    initial clk = 1'b0;
    always #(CLK_PERIOD/2) clk = ~clk;

    initial begin
        $display("=== PIPELINE MAC Testbench ===");

        rst_n     = 1'b0;
        clear_acc = 1'b0;
        valid_in  = 1'b0;
        a         = '0;
        b         = '0;
        repeat (3) @(posedge clk);
        rst_n = 1'b1;
        @(posedge clk);

        // Compute: 3*4 = 12, then accumulate 5*6 = 30 -> total = 42
        $display("  Computing 3*4 + 5*6 = 42");

        // Feed first pair with clear
        @(posedge clk);
        a = 8'd3; b = 8'd4;
        valid_in  = 1'b1;
        clear_acc = 1'b1;
        @(posedge clk);
        // Feed second pair (accumulate)
        a = 8'd5; b = 8'd6;
        clear_acc = 1'b0;
        @(posedge clk);
        valid_in = 1'b0;
        a = '0; b = '0;

        // Wait for pipeline to flush (3 stage latency)
        repeat (5) @(posedge clk);
        #1;
        $display("  acc_out = %0d (expected 42)", acc_out);
        assert (acc_out == 24'd42)
            else $error("MAC: expected 42, got %0d", acc_out);
        $display("  MAC accumulate test  PASS");

        // Clear and compute dot product: sum of i*i for i=1..4 = 1+4+9+16 = 30
        $display("  Computing dot product: 1^2 + 2^2 + 3^2 + 4^2 = 30");
        @(posedge clk);
        clear_acc = 1'b1;
        valid_in  = 1'b1;
        a = 8'd1; b = 8'd1;
        @(posedge clk);
        clear_acc = 1'b0;
        a = 8'd2; b = 8'd2;
        @(posedge clk);
        a = 8'd3; b = 8'd3;
        @(posedge clk);
        a = 8'd4; b = 8'd4;
        @(posedge clk);
        valid_in = 1'b0;

        repeat (5) @(posedge clk);
        #1;
        $display("  acc_out = %0d (expected 30)", acc_out);
        assert (acc_out == 24'd30)
            else $error("Dot product: expected 30, got %0d", acc_out);
        $display("  Dot product test  PASS");

        $display("=== PIPELINE MAC All Tests Passed ===");
        $finish;
    end

    initial begin
        #100000;
        $error("Simulation timeout!");
        $finish;
    end

endmodule
