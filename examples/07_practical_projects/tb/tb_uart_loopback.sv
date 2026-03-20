// Testbench: UART TX + RX Loopback
// Connects UART transmitter output directly to receiver input
// to verify end-to-end data integrity.

`timescale 1ns / 1ps

module tb_uart_loopback;

    parameter CLK_PERIOD    = 10;
    parameter BAUD_DIV      = 8;
    parameter BAUD_DIV_16X  = 0;   // 16x oversampling divider (0 = divide by 1)

    logic       clk, rst_n;
    logic [7:0] tx_data;
    logic       tx_valid, tx_ready;
    logic       serial_line;
    logic [7:0] rx_data;
    logic       rx_valid, frame_error;

    uart_tx #(.BAUD_DIV(BAUD_DIV)) u_tx (
        .clk      (clk),
        .rst_n    (rst_n),
        .tx_data  (tx_data),
        .tx_valid (tx_valid),
        .tx_ready (tx_ready),
        .tx_out   (serial_line)
    );

    uart_rx #(.BAUD_DIV_16X(BAUD_DIV_16X)) u_rx (
        .clk         (clk),
        .rst_n       (rst_n),
        .rx_in       (serial_line),
        .rx_data     (rx_data),
        .rx_valid    (rx_valid),
        .frame_error (frame_error)
    );

    initial clk = 1'b0;
    always #(CLK_PERIOD/2) clk = ~clk;

    logic [7:0] test_bytes [4] = '{8'h00, 8'hFF, 8'h55, 8'hA3};

    initial begin
        $display("=== UART LOOPBACK Testbench ===");

        rst_n    = 1'b0;
        tx_valid = 1'b0;
        tx_data  = '0;
        repeat (5) @(posedge clk);
        rst_n = 1'b1;
        repeat (10) @(posedge clk);

        for (int i = 0; i < 4; i++) begin
            // Send byte
            @(posedge clk);
            tx_data  = test_bytes[i];
            tx_valid = 1'b1;
            @(posedge clk);
            tx_valid = 1'b0;

            // Wait for reception
            wait (rx_valid);
            @(posedge clk);
            #1;
            $display("  TX: 0x%02h -> RX: 0x%02h  frame_error=%0b  %s",
                     test_bytes[i], rx_data, frame_error,
                     (rx_data == test_bytes[i] && !frame_error) ? "PASS" : "FAIL");

            // Wait for TX ready before next byte
            wait (tx_ready);
            repeat (5) @(posedge clk);
        end

        $display("=== UART LOOPBACK Complete ===");
        $finish;
    end

    initial begin
        #2000000;
        $error("Simulation timeout!");
        $finish;
    end

endmodule
