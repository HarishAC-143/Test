// Testbench for UART Transceiver (TX + RX loopback)

module tb_uart;

    localparam int CLK_FREQ  = 50_000_000;
    localparam int BAUD_RATE = 115200;
    localparam int BIT_PERIOD_NS = 1_000_000_000 / BAUD_RATE;  // ~8680 ns

    logic       clk;
    logic       rst_n;

    // TX signals
    logic       tx_start;
    logic [7:0] tx_data;
    logic       tx_out;
    logic       tx_busy;
    logic       tx_done;

    // RX signals
    logic [7:0] rx_data;
    logic       rx_valid;
    logic       rx_error;

    int error_count = 0;

    uart_tx #(
        .CLK_FREQ (CLK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) tx_inst (
        .clk     (clk),
        .rst_n   (rst_n),
        .tx_start(tx_start),
        .tx_data (tx_data),
        .tx_out  (tx_out),
        .tx_busy (tx_busy),
        .tx_done (tx_done)
    );

    uart_rx #(
        .CLK_FREQ (CLK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) rx_inst (
        .clk     (clk),
        .rst_n   (rst_n),
        .rx_in   (tx_out),   // Loopback: TX output -> RX input
        .rx_data (rx_data),
        .rx_valid(rx_valid),
        .rx_error(rx_error)
    );

    initial begin
        clk = 0;
        forever #10 clk = ~clk;  // 50 MHz
    end

    task automatic send_byte(input logic [7:0] data);
        @(posedge clk);
        tx_data  <= data;
        tx_start <= 1'b1;
        @(posedge clk);
        tx_start <= 1'b0;

        // Wait for TX to complete
        while (!tx_done) @(posedge clk);
    endtask

    task automatic wait_rx(output logic [7:0] data, output logic valid);
        int timeout = 0;
        valid = 0;
        while (!rx_valid && timeout < 100_000) begin
            @(posedge clk);
            timeout++;
        end
        if (rx_valid) begin
            data  = rx_data;
            valid = 1;
        end
    endtask

    logic [7:0] received;
    logic       recv_valid;

    initial begin
        $display("=== UART Transceiver Testbench (Loopback) ===");
        $display("Baud rate: %0d, Bit period: %0d ns", BAUD_RATE, BIT_PERIOD_NS);
        $display("");

        rst_n    = 0;
        tx_start = 0;
        tx_data  = '0;

        repeat (10) @(posedge clk);
        rst_n = 1;
        repeat (5) @(posedge clk);

        // Test 1: Send 0x55 (alternating bits)
        $display("[Test 1] Send 0x55 (01010101)");
        send_byte(8'h55);
        wait_rx(received, recv_valid);
        if (recv_valid && received === 8'h55) begin
            $display("[PASS] Received 0x%02h", received);
        end else begin
            $error("[FAIL] Expected 0x55, got 0x%02h (valid=%b)", received, recv_valid);
            error_count++;
        end

        repeat (100) @(posedge clk);

        // Test 2: Send 0xAA
        $display("[Test 2] Send 0xAA (10101010)");
        send_byte(8'hAA);
        wait_rx(received, recv_valid);
        if (recv_valid && received === 8'hAA) begin
            $display("[PASS] Received 0x%02h", received);
        end else begin
            $error("[FAIL] Expected 0xAA, got 0x%02h (valid=%b)", received, recv_valid);
            error_count++;
        end

        repeat (100) @(posedge clk);

        // Test 3: Send 0x00
        $display("[Test 3] Send 0x00 (all zeros)");
        send_byte(8'h00);
        wait_rx(received, recv_valid);
        if (recv_valid && received === 8'h00) begin
            $display("[PASS] Received 0x%02h", received);
        end else begin
            $error("[FAIL] Expected 0x00, got 0x%02h", received);
            error_count++;
        end

        repeat (100) @(posedge clk);

        // Test 4: Send 0xFF
        $display("[Test 4] Send 0xFF (all ones)");
        send_byte(8'hFF);
        wait_rx(received, recv_valid);
        if (recv_valid && received === 8'hFF) begin
            $display("[PASS] Received 0x%02h", received);
        end else begin
            $error("[FAIL] Expected 0xFF, got 0x%02h", received);
            error_count++;
        end

        repeat (100) @(posedge clk);

        // Test 5: Send multiple bytes in sequence
        $display("[Test 5] Send string 'HELLO'");
        for (int i = 0; i < 5; i++) begin
            automatic logic [7:0] chars [5] = '{"H", "E", "L", "L", "O"};
            send_byte(chars[i]);
            wait_rx(received, recv_valid);
            if (recv_valid && received === chars[i]) begin
                $display("[PASS] Char '%c' (0x%02h) received", received, received);
            end else begin
                $error("[FAIL] Expected '%c', got 0x%02h", chars[i], received);
                error_count++;
            end
            repeat (50) @(posedge clk);
        end

        // Test 6: Verify no framing errors
        $display("[Test 6] Verify no framing errors");
        if (rx_error === 1'b0) begin
            $display("[PASS] No framing errors detected");
        end else begin
            $error("[FAIL] Framing error detected");
            error_count++;
        end

        $display("");
        if (error_count == 0)
            $display("ALL TESTS PASSED");
        else
            $display("%0d FAILURES DETECTED", error_count);

        $finish;
    end

    // Timeout
    initial begin
        #100_000_000;
        $error("TIMEOUT");
        $finish;
    end

endmodule
