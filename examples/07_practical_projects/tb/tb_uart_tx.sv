// Testbench: UART Transmitter

`timescale 1ns / 1ps

module tb_uart_tx;

    parameter CLK_PERIOD = 10;
    parameter BAUD_DIV   = 8;   // fast for simulation

    logic       clk, rst_n;
    logic [7:0] tx_data;
    logic       tx_valid, tx_ready, tx_out;

    uart_tx #(.BAUD_DIV(BAUD_DIV)) u_dut (.*);

    initial clk = 1'b0;
    always #(CLK_PERIOD/2) clk = ~clk;

    // Monitor task: captures transmitted byte by sampling tx_out
    task automatic capture_byte(output logic [7:0] captured);
        // Wait for start bit (falling edge on tx_out)
        @(negedge tx_out);

        // Wait to center of start bit
        repeat (BAUD_DIV / 2) @(posedge clk);

        // Sample 8 data bits (LSB first)
        for (int i = 0; i < 8; i++) begin
            repeat (BAUD_DIV + 1) @(posedge clk);
            captured[i] = tx_out;
        end

        // Wait for stop bit
        repeat (BAUD_DIV + 1) @(posedge clk);
        assert (tx_out == 1'b1)
            else $error("Stop bit: expected HIGH");
    endtask

    logic [7:0] received;

    initial begin
        $display("=== UART TX Testbench ===");

        rst_n    = 1'b0;
        tx_valid = 1'b0;
        tx_data  = '0;
        repeat (5) @(posedge clk);
        rst_n = 1'b1;
        repeat (3) @(posedge clk);

        // Verify idle state
        #1;
        assert (tx_ready == 1'b1 && tx_out == 1'b1)
            else $error("Idle: ready=%0b, tx_out=%0b", tx_ready, tx_out);
        $display("  Idle state: ready=%0b tx_out=%0b  PASS", tx_ready, tx_out);

        // Transmit 0x55 (alternating bits)
        $display("  Transmitting 0x55...");
        @(posedge clk);
        tx_data  = 8'h55;
        tx_valid = 1'b1;
        @(posedge clk);
        tx_valid = 1'b0;

        capture_byte(received);
        assert (received == 8'h55)
            else $error("TX 0x55: received 0x%02h", received);
        $display("  Received: 0x%02h  PASS", received);

        // Wait for ready
        wait (tx_ready);
        repeat (3) @(posedge clk);

        // Transmit 0xA3
        $display("  Transmitting 0xA3...");
        @(posedge clk);
        tx_data  = 8'hA3;
        tx_valid = 1'b1;
        @(posedge clk);
        tx_valid = 1'b0;

        capture_byte(received);
        assert (received == 8'hA3)
            else $error("TX 0xA3: received 0x%02h", received);
        $display("  Received: 0x%02h  PASS", received);

        wait (tx_ready);
        $display("=== UART TX All Tests Passed ===");
        $finish;
    end

    initial begin
        #500000;
        $error("Simulation timeout!");
        $finish;
    end

endmodule
