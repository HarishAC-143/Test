// ============================================================================
// Testbench: UART Loopback
// ============================================================================
// Tests the UART TX and RX modules together by connecting tx_out to rx_in
// (loopback). Verifies that data transmitted is correctly received.
// ============================================================================

`timescale 1ns / 1ps

module tb_uart;

    parameter int CLK_FREQ  = 50_000_000;
    parameter int BAUD_RATE = 115200;
    parameter int DATA_BITS = 8;

    localparam int CLK_PERIOD = 1_000_000_000 / CLK_FREQ;  // in ns

    logic                  clk, rst_n;
    logic [DATA_BITS-1:0]  tx_data;
    logic                  tx_valid, tx_ready;
    logic                  serial_line;
    logic [DATA_BITS-1:0]  rx_data;
    logic                  rx_valid, rx_error;

    // Clock generation
    initial clk = 1'b0;
    always #(CLK_PERIOD/2) clk = ~clk;

    // TX instance
    uart_tx #(
        .CLK_FREQ  (CLK_FREQ),
        .BAUD_RATE (BAUD_RATE),
        .DATA_BITS (DATA_BITS)
    ) u_tx (
        .clk      (clk),
        .rst_n    (rst_n),
        .tx_data  (tx_data),
        .tx_valid (tx_valid),
        .tx_ready (tx_ready),
        .tx_out   (serial_line)
    );

    // RX instance — loopback
    uart_rx #(
        .CLK_FREQ  (CLK_FREQ),
        .BAUD_RATE (BAUD_RATE),
        .DATA_BITS (DATA_BITS)
    ) u_rx (
        .clk      (clk),
        .rst_n    (rst_n),
        .rx_in    (serial_line),
        .rx_data  (rx_data),
        .rx_valid (rx_valid),
        .rx_error (rx_error)
    );

    // Test
    int pass_count = 0;
    int fail_count = 0;

    task automatic send_byte(input logic [DATA_BITS-1:0] data);
        wait (tx_ready);
        @(posedge clk);
        tx_data  <= data;
        tx_valid <= 1'b1;
        @(posedge clk);
        tx_valid <= 1'b0;
    endtask

    task automatic wait_and_check(input logic [DATA_BITS-1:0] expected);
        wait (rx_valid);
        @(negedge clk);
        if (rx_data === expected) begin
            $display("[%0t] PASS: TX=0x%0h, RX=0x%0h", $time, expected, rx_data);
            pass_count++;
        end else begin
            $error("[%0t] FAIL: TX=0x%0h, RX=0x%0h", $time, expected, rx_data);
            fail_count++;
        end
        @(posedge clk);
    endtask

    initial begin
        $display("========================================");
        $display("  UART Loopback Testbench");
        $display("  Baud=%0d, Data=%0d bits", BAUD_RATE, DATA_BITS);
        $display("========================================");

        rst_n    <= 1'b0;
        tx_valid <= 1'b0;
        tx_data  <= '0;
        repeat (10) @(posedge clk);
        rst_n <= 1'b1;
        repeat (5) @(posedge clk);

        // Test: Send several bytes
        fork
            begin
                send_byte(8'h55);
                send_byte(8'hAA);
                send_byte(8'h00);
                send_byte(8'hFF);
                send_byte(8'h42);
            end
            begin
                wait_and_check(8'h55);
                wait_and_check(8'hAA);
                wait_and_check(8'h00);
                wait_and_check(8'hFF);
                wait_and_check(8'h42);
            end
        join

        $display("\n========================================");
        $display("  PASS=%0d  FAIL=%0d", pass_count, fail_count);
        if (fail_count == 0)
            $display("  *** ALL TESTS PASSED ***");
        else
            $display("  *** SOME TESTS FAILED ***");
        $display("========================================");
        $finish;
    end

    initial begin
        #50ms;
        $fatal(1, "Simulation timed out!");
    end

    initial begin
        $dumpfile("tb_uart.vcd");
        $dumpvars(0, tb_uart);
    end

endmodule
