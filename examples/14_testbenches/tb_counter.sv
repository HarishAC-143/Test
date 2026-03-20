// Testbench for Up Counter
// Demonstrates basic testbench structure: clock generation, reset sequence,
// stimulus, and self-checking with assertions.

`timescale 1ns / 1ps

module tb_counter;

    // =========================================================================
    // Parameters
    // =========================================================================
    localparam int WIDTH     = 8;
    localparam int MAX_COUNT = 15;
    localparam int CLK_PERIOD = 10;

    // =========================================================================
    // DUT Signals
    // =========================================================================
    logic             clk;
    logic             rst_n;
    logic             enable;
    logic             clear;
    logic [WIDTH-1:0] count;
    logic             terminal_count;

    // =========================================================================
    // Clock Generation
    // =========================================================================
    initial clk = 1'b0;
    always #(CLK_PERIOD/2) clk = ~clk;

    // =========================================================================
    // DUT Instantiation
    // =========================================================================
    up_counter #(
        .WIDTH     (WIDTH),
        .MAX_COUNT (MAX_COUNT)
    ) u_dut (
        .clk            (clk),
        .rst_n          (rst_n),
        .enable         (enable),
        .clear          (clear),
        .count          (count),
        .terminal_count (terminal_count)
    );

    // =========================================================================
    // Tasks for common operations
    // =========================================================================
    task automatic reset_dut();
        rst_n  <= 1'b0;
        enable <= 1'b0;
        clear  <= 1'b0;
        repeat (5) @(posedge clk);
        rst_n  <= 1'b1;
        @(posedge clk);
    endtask

    task automatic wait_clocks(input int n);
        repeat (n) @(posedge clk);
    endtask

    // =========================================================================
    // Test Stimulus
    // =========================================================================
    int error_count = 0;

    initial begin
        $display("============================================");
        $display("  Counter Testbench Starting");
        $display("============================================");

        // Test 1: Reset behavior
        $display("\n[TEST 1] Reset behavior");
        reset_dut();
        assert (count == 0) else begin
            $error("FAIL: Count should be 0 after reset, got %0d", count);
            error_count++;
        end
        $display("  PASS: Count = %0d after reset", count);

        // Test 2: Count up
        $display("\n[TEST 2] Count up");
        enable <= 1'b1;
        for (int i = 1; i <= MAX_COUNT; i++) begin
            @(posedge clk);
            #1;
            assert (count == i) else begin
                $error("FAIL: Expected count=%0d, got %0d", i, count);
                error_count++;
            end
        end
        $display("  PASS: Counted up to %0d", count);

        // Test 3: Terminal count and wraparound
        $display("\n[TEST 3] Terminal count and wraparound");
        @(posedge clk);
        #1;
        assert (count == 0) else begin
            $error("FAIL: Count should wrap to 0, got %0d", count);
            error_count++;
        end
        $display("  PASS: Counter wrapped to 0");

        // Test 4: Clear functionality
        $display("\n[TEST 4] Clear functionality");
        wait_clocks(5);
        clear <= 1'b1;
        @(posedge clk);
        #1;
        clear <= 1'b0;
        assert (count == 0) else begin
            $error("FAIL: Count should be 0 after clear, got %0d", count);
            error_count++;
        end
        $display("  PASS: Count cleared to 0");

        // Test 5: Enable gate
        $display("\n[TEST 5] Enable gate");
        enable <= 1'b0;
        wait_clocks(5);
        assert (count == 0) else begin
            $error("FAIL: Count should remain 0 when disabled, got %0d", count);
            error_count++;
        end
        $display("  PASS: Counter held at %0d when disabled", count);

        // Report
        $display("\n============================================");
        if (error_count == 0)
            $display("  ALL TESTS PASSED");
        else
            $display("  %0d TEST(S) FAILED", error_count);
        $display("============================================");

        $finish;
    end

    // Timeout watchdog
    initial begin
        #100000;
        $error("TIMEOUT: Simulation exceeded time limit");
        $finish;
    end

    // Waveform dump
    initial begin
        $dumpfile("tb_counter.vcd");
        $dumpvars(0, tb_counter);
    end

endmodule
