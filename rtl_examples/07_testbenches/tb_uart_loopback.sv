// =============================================================================
// UART Loopback Testbench
// Connects UART TX to UART RX and verifies data integrity.
// =============================================================================

`timescale 1ns / 1ps

module tb_uart_loopback;

    parameter CLK_FREQ  = 50_000_000;
    parameter BAUD_RATE = 1_000_000;   // Fast baud for simulation
    parameter CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;

    logic       clk;
    logic       rst_n;

    // TX signals
    logic       tx_valid;
    logic [7:0] tx_data;
    logic       tx_out;
    logic       tx_busy;

    // RX signals
    logic [7:0] rx_data;
    logic       rx_valid;
    logic       rx_error;

    // Loopback: TX output feeds RX input
    wire rx_in = tx_out;

    uart_tx #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) u_tx (
        .clk      (clk),
        .rst_n    (rst_n),
        .tx_valid (tx_valid),
        .tx_data  (tx_data),
        .tx_out   (tx_out),
        .tx_busy  (tx_busy)
    );

    uart_rx #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) u_rx (
        .clk      (clk),
        .rst_n    (rst_n),
        .rx_in    (rx_in),
        .rx_data  (rx_data),
        .rx_valid (rx_valid),
        .rx_error (rx_error)
    );

    // Clock: 20 ns period (50 MHz)
    initial clk = 0;
    always #10 clk = ~clk;

    int pass_count = 0;
    int fail_count = 0;

    task automatic send_byte(input logic [7:0] data);
        @(posedge clk);
        tx_valid = 1;
        tx_data  = data;
        @(posedge clk);
        tx_valid = 0;

        // Wait for TX to complete
        wait (!tx_busy);
        // Wait for RX to latch data
        @(posedge rx_valid);
        @(posedge clk);

        if (rx_data !== data) begin
            $display("[FAIL] Sent 0x%02h, Received 0x%02h", data, rx_data);
            fail_count++;
        end else begin
            $display("[PASS] Loopback: 0x%02h", data);
            pass_count++;
        end

        if (rx_error) begin
            $display("[FAIL] Framing error detected");
            fail_count++;
        end
    endtask

    initial begin
        $display("========================================");
        $display("     UART Loopback Testbench");
        $display("========================================");

        rst_n    = 0;
        tx_valid = 0;
        tx_data  = 0;
        repeat (10) @(posedge clk);
        rst_n = 1;
        repeat (5) @(posedge clk);

        // Test specific patterns
        send_byte(8'h00);
        send_byte(8'hFF);
        send_byte(8'hA5);
        send_byte(8'h5A);
        send_byte(8'h55);
        send_byte(8'hAA);

        // Test sequential values
        for (int i = 0; i < 10; i++) begin
            send_byte(8'(i));
        end

        $display("\n========================================");
        $display("  Results: %0d PASS, %0d FAIL", pass_count, fail_count);
        $display("========================================");
        $finish;
    end

    // Timeout
    initial begin
        #50_000_000;
        $display("[ERROR] Simulation timeout!");
        $finish;
    end

endmodule
