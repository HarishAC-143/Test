// ============================================================================
// Testbench: Synchronous FIFO
// ============================================================================
// Comprehensive testbench demonstrating:
//   - Clock and reset generation
//   - Reusable tasks for stimulus and checking
//   - Scoreboard-based self-checking
//   - Multiple test scenarios
//   - Timeout watchdog
//   - Final pass/fail report
// ============================================================================

`timescale 1ns / 1ps

module tb_sync_fifo;

    // -------------------------------------------------------------------------
    // Parameters
    // -------------------------------------------------------------------------
    parameter int WIDTH = 8;
    parameter int DEPTH = 16;

    // -------------------------------------------------------------------------
    // Signals
    // -------------------------------------------------------------------------
    logic             clk, rst_n;
    logic             wr_en, rd_en;
    logic [WIDTH-1:0] wr_data, rd_data;
    logic             full, empty, almost_full, almost_empty;
    logic [$clog2(DEPTH):0] count;

    // -------------------------------------------------------------------------
    // Clock generation: 100 MHz (10 ns period)
    // -------------------------------------------------------------------------
    initial clk = 1'b0;
    always #5ns clk = ~clk;

    // -------------------------------------------------------------------------
    // DUT instantiation
    // -------------------------------------------------------------------------
    sync_fifo #(
        .WIDTH (WIDTH),
        .DEPTH (DEPTH)
    ) dut (
        .clk          (clk),
        .rst_n        (rst_n),
        .wr_en        (wr_en),
        .wr_data      (wr_data),
        .rd_en        (rd_en),
        .rd_data      (rd_data),
        .full         (full),
        .empty        (empty),
        .almost_full  (almost_full),
        .almost_empty (almost_empty),
        .count        (count)
    );

    // -------------------------------------------------------------------------
    // Scoreboard
    // -------------------------------------------------------------------------
    logic [WIDTH-1:0] expected_queue [$];
    int pass_count = 0;
    int fail_count = 0;

    // -------------------------------------------------------------------------
    // Reusable Tasks
    // -------------------------------------------------------------------------

    task automatic reset_dut();
        $display("[%0t] Resetting DUT...", $time);
        rst_n   <= 1'b0;
        wr_en   <= 1'b0;
        rd_en   <= 1'b0;
        wr_data <= '0;
        repeat (5) @(posedge clk);
        rst_n <= 1'b1;
        @(posedge clk);
        $display("[%0t] Reset complete.", $time);
    endtask

    task automatic write_one(input logic [WIDTH-1:0] data);
        @(posedge clk);
        wr_en   <= 1'b1;
        wr_data <= data;
        @(posedge clk);
        wr_en <= 1'b0;
        expected_queue.push_back(data);
    endtask

    task automatic read_and_check();
        @(posedge clk);
        rd_en <= 1'b1;
        @(posedge clk);
        rd_en <= 1'b0;
        @(negedge clk);  // sample on falling edge for stability
        if (expected_queue.size() > 0) begin
            automatic logic [WIDTH-1:0] exp = expected_queue.pop_front();
            if (rd_data === exp) begin
                pass_count++;
            end else begin
                $error("[%0t] MISMATCH: got 0x%0h, expected 0x%0h",
                       $time, rd_data, exp);
                fail_count++;
            end
        end
    endtask

    task automatic write_burst(input int num, input bit random_data = 1);
        for (int i = 0; i < num; i++) begin
            automatic logic [WIDTH-1:0] data;
            data = random_data ? $urandom_range(0, (2**WIDTH)-1) : i[WIDTH-1:0];
            write_one(data);
        end
    endtask

    task automatic read_burst(input int num);
        for (int i = 0; i < num; i++)
            read_and_check();
    endtask

    // -------------------------------------------------------------------------
    // Test Scenarios
    // -------------------------------------------------------------------------

    initial begin
        $display("========================================");
        $display("  Synchronous FIFO Testbench");
        $display("  WIDTH=%0d, DEPTH=%0d", WIDTH, DEPTH);
        $display("========================================");

        reset_dut();

        // --- Test 1: Empty flag after reset ---
        $display("\n=== Test 1: Empty after reset ===");
        assert (empty)  else begin $error("FIFO not empty after reset!"); fail_count++; end
        assert (!full)  else begin $error("FIFO full after reset!"); fail_count++; end
        assert (count == 0) else begin $error("Count != 0 after reset!"); fail_count++; end
        pass_count += 3;
        $display("  PASSED: empty=%b, full=%b, count=%0d", empty, full, count);

        // --- Test 2: Sequential write then read ---
        $display("\n=== Test 2: Fill and drain (sequential write/read) ===");
        write_burst(DEPTH, .random_data(0));
        @(posedge clk);
        assert (full) else begin $error("FIFO should be full!"); fail_count++; end
        $display("  After fill: full=%b, count=%0d", full, count);
        read_burst(DEPTH);
        @(posedge clk);
        assert (empty) else begin $error("FIFO should be empty!"); fail_count++; end
        $display("  After drain: empty=%b, count=%0d", empty, count);

        // --- Test 3: Simultaneous read and write ---
        $display("\n=== Test 3: Simultaneous read/write ===");
        write_burst(4, .random_data(1));
        fork
            begin
                for (int i = 0; i < 20; i++)
                    write_one($urandom_range(0, 255));
            end
            begin
                repeat (2) @(posedge clk);
                for (int i = 0; i < 20; i++)
                    read_and_check();
            end
        join
        // Drain any remaining
        while (!empty) read_and_check();

        // --- Test 4: Write to full FIFO (should not corrupt) ---
        $display("\n=== Test 4: Over-write protection ===");
        write_burst(DEPTH, .random_data(0));
        @(posedge clk);
        assert (full) else $error("Expected full!");
        // Attempt extra write
        wr_en   <= 1'b1;
        wr_data <= 8'hFF;
        @(posedge clk);
        wr_en <= 1'b0;
        @(posedge clk);
        assert (count == DEPTH[$clog2(DEPTH):0])
            else begin $error("Count changed on full write!"); fail_count++; end
        pass_count++;
        $display("  Write to full FIFO correctly blocked. count=%0d", count);
        // Drain
        for (int i = 0; i < DEPTH; i++) read_and_check();

        // --- Test 5: Read from empty FIFO ---
        $display("\n=== Test 5: Under-read protection ===");
        @(posedge clk);
        assert (empty) else $error("Expected empty!");
        rd_en <= 1'b1;
        @(posedge clk);
        rd_en <= 1'b0;
        @(posedge clk);
        assert (count == 0) else begin $error("Count changed on empty read!"); fail_count++; end
        pass_count++;
        $display("  Read from empty FIFO correctly blocked. count=%0d", count);

        // --- Final Report ---
        $display("\n========================================");
        $display("  RESULTS: PASS=%0d  FAIL=%0d", pass_count, fail_count);
        if (fail_count == 0)
            $display("  *** ALL TESTS PASSED ***");
        else
            $display("  *** SOME TESTS FAILED ***");
        $display("========================================\n");

        $finish;
    end

    // -------------------------------------------------------------------------
    // Timeout watchdog
    // -------------------------------------------------------------------------
    initial begin
        #200us;
        $fatal(1, "Simulation timed out after 200us!");
    end

    // -------------------------------------------------------------------------
    // Waveform dump (for debugging)
    // -------------------------------------------------------------------------
    initial begin
        $dumpfile("tb_sync_fifo.vcd");
        $dumpvars(0, tb_sync_fifo);
    end

endmodule
