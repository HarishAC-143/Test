// =============================================================================
// Testbench for Moore & Mealy Sequence Detectors
// Drives a known bit stream and verifies detection of "1011".
// =============================================================================

`timescale 1ns / 1ps

module tb_fsm_sequence_detector;

    logic clk, rst_n, data_in;
    logic moore_detected, mealy_detected;

    moore_sequence_detector u_moore (
        .clk      (clk),
        .rst_n    (rst_n),
        .data_in  (data_in),
        .detected (moore_detected)
    );

    mealy_sequence_detector u_mealy (
        .clk      (clk),
        .rst_n    (rst_n),
        .data_in  (data_in),
        .detected (mealy_detected)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    // Known input sequence: 1 0 1 1 0 1 1 0 1 0 1 1 1 0
    // Expected "1011" detections at different times for Moore vs Mealy
    logic [13:0] input_sequence = 14'b10110110101110;

    int moore_count = 0;
    int mealy_count = 0;

    initial begin
        $display("========================================");
        $display("  Sequence Detector Testbench (\"1011\")");
        $display("========================================");
        $display("Bit# | Input | Moore_Det | Mealy_Det");
        $display("-----|-------|-----------|----------");

        rst_n   = 0;
        data_in = 0;
        repeat (3) @(posedge clk);
        rst_n = 1;

        for (int i = 13; i >= 0; i--) begin
            @(negedge clk);
            data_in = input_sequence[i];
            @(posedge clk);
            #1;
            $display("  %2d |   %b   |     %b     |     %b",
                     13 - i, data_in, moore_detected, mealy_detected);
            if (moore_detected) moore_count++;
            if (mealy_detected) mealy_count++;
        end

        // Additional clocks to flush pipeline
        @(posedge clk); #1;
        if (moore_detected) moore_count++;

        $display("\n========================================");
        $display("  Moore detections: %0d", moore_count);
        $display("  Mealy detections: %0d", mealy_count);
        $display("  (Mealy detects 1 cycle earlier than Moore)");
        $display("========================================");
        $finish;
    end

endmodule
