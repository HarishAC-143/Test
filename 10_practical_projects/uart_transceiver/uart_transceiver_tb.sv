// UART loopback testbench — connects TX output to RX input.

module uart_transceiver_tb;

    localparam int CLK_PERIOD     = 10;    // 100 MHz
    localparam int CLK_DIV_WIDTH  = 16;
    localparam int BAUD_DIV       = 867;   // 100MHz / 868 ≈ 115200 baud

    logic                     clk, rst_n;
    logic [CLK_DIV_WIDTH-1:0] clk_div;

    // TX signals
    logic [7:0] tx_data;
    logic       tx_valid, tx_ready;
    logic       txd;

    // RX signals
    logic [7:0] rx_data;
    logic       rx_valid, frame_error;

    uart_tx #(.CLK_DIV_WIDTH(CLK_DIV_WIDTH)) u_tx (
        .clk      (clk),
        .rst_n    (rst_n),
        .clk_div  (clk_div),
        .tx_data  (tx_data),
        .tx_valid (tx_valid),
        .tx_ready (tx_ready),
        .txd      (txd)
    );

    uart_rx #(.CLK_DIV_WIDTH(CLK_DIV_WIDTH)) u_rx (
        .clk         (clk),
        .rst_n       (rst_n),
        .clk_div     (clk_div),
        .rxd         (txd),          // loopback
        .rx_data     (rx_data),
        .rx_valid    (rx_valid),
        .frame_error (frame_error)
    );

    initial clk = 1'b0;
    always #(CLK_PERIOD/2) clk = ~clk;

    int error_count = 0;
    int pass_count  = 0;

    task automatic send_and_verify(input logic [7:0] data);
        // Wait for TX ready
        while (!tx_ready) @(posedge clk);

        tx_data  = data;
        tx_valid = 1'b1;
        @(posedge clk);
        tx_valid = 1'b0;

        // Wait for RX valid
        @(posedge rx_valid);
        @(posedge clk);

        if (rx_data === data && !frame_error) begin
            $display("PASS: TX=0x%02h RX=0x%02h", data, rx_data);
            pass_count++;
        end else begin
            $display("FAIL: TX=0x%02h RX=0x%02h frame_error=%0b",
                     data, rx_data, frame_error);
            error_count++;
        end
    endtask

    initial begin
        $display("=== UART Loopback Testbench ===");
        $display("Baud divider: %0d\n", BAUD_DIV);

        rst_n    = 1'b0;
        tx_valid = 1'b0;
        tx_data  = '0;
        clk_div  = BAUD_DIV;

        repeat (10) @(posedge clk);
        rst_n = 1'b1;
        repeat (5) @(posedge clk);

        send_and_verify(8'h55);
        send_and_verify(8'hAA);
        send_and_verify(8'h00);
        send_and_verify(8'hFF);
        send_and_verify(8'h42);
        send_and_verify(8'hDE);
        send_and_verify(8'hAD);

        // Random data
        for (int i = 0; i < 5; i++)
            send_and_verify($urandom & 8'hFF);

        $display("\nResults: %0d passed, %0d failed", pass_count, error_count);
        if (error_count == 0)
            $display("*** ALL TESTS PASSED ***");
        $finish;
    end

    initial begin
        $dumpfile("uart.vcd");
        $dumpvars(0, uart_transceiver_tb);
        #(CLK_PERIOD * 500000);
        $display("TIMEOUT: simulation exceeded time limit");
        $finish;
    end

endmodule
