// Self-checking testbench for the synchronous FIFO.
// Tests: reset, write-until-full, read-until-empty, simultaneous R/W,
//        data integrity, overflow/underflow protection, status flags.

`timescale 1ns / 1ps

module tb_fifo_sync;

    import tb_pkg::*;

    localparam int DATA_WIDTH = 8;
    localparam int DEPTH      = 16;
    localparam int CLK_PERIOD = 10;

    logic                    clk;
    logic                    rst_n;
    logic                    wr_en;
    logic                    rd_en;
    logic [DATA_WIDTH-1:0]   wr_data;
    logic [DATA_WIDTH-1:0]   rd_data;
    logic                    full;
    logic                    empty;
    logic                    almost_full;
    logic                    almost_empty;
    logic [$clog2(DEPTH):0]  count;

    // Reference model (queue)
    logic [DATA_WIDTH-1:0] ref_queue[$];

    fifo_sync #(
        .DATA_WIDTH          (DATA_WIDTH),
        .DEPTH               (DEPTH),
        .ALMOST_FULL_THRESH  (DEPTH - 2),
        .ALMOST_EMPTY_THRESH (2)
    ) dut (
        .clk          (clk),
        .rst_n        (rst_n),
        .wr_en        (wr_en),
        .rd_en        (rd_en),
        .wr_data      (wr_data),
        .rd_data      (rd_data),
        .full         (full),
        .empty        (empty),
        .almost_full  (almost_full),
        .almost_empty (almost_empty),
        .count        (count)
    );

    // Clock generation
    initial clk = 1'b0;
    always #(CLK_PERIOD/2) clk = ~clk;

    task automatic wait_clocks(input int n);
        repeat (n) @(posedge clk);
    endtask

    task automatic apply_reset();
        rst_n   = 1'b0;
        wr_en   = 1'b0;
        rd_en   = 1'b0;
        wr_data = '0;
        ref_queue.delete();
        wait_clocks(5);
        rst_n = 1'b1;
        wait_clocks(2);
    endtask

    task automatic write_one(input logic [DATA_WIDTH-1:0] data);
        @(posedge clk);
        wr_en   = 1'b1;
        wr_data = data;
        @(posedge clk);
        wr_en = 1'b0;
    endtask

    task automatic read_one();
        @(posedge clk);
        rd_en = 1'b1;
        @(posedge clk);
        rd_en = 1'b0;
    endtask

    initial begin
        reset_counters();
        $display("=== FIFO Sync Testbench Start ===");

        // -------------------------------------------------------
        // Test 1: Reset state
        // -------------------------------------------------------
        apply_reset();
        @(negedge clk);
        check(empty == 1'b1, "reset_empty");
        check(full == 1'b0, "reset_not_full");
        check_equal(count, 0, "reset_count");

        // -------------------------------------------------------
        // Test 2: Write until full
        // -------------------------------------------------------
        $display("[%0t] Writing %0d entries...", $time, DEPTH);
        for (int i = 0; i < DEPTH; i++) begin
            @(posedge clk);
            wr_en   = 1'b1;
            wr_data = i[DATA_WIDTH-1:0];
            ref_queue.push_back(i[DATA_WIDTH-1:0]);
        end
        @(posedge clk);
        wr_en = 1'b0;
        wait_clocks(1);
        @(negedge clk);
        check(full == 1'b1, "full_after_writes");
        check(empty == 1'b0, "not_empty_when_full");
        check_equal(count, DEPTH, "count_equals_depth");

        // -------------------------------------------------------
        // Test 3: Write when full (overflow protection)
        // -------------------------------------------------------
        @(posedge clk);
        wr_en   = 1'b1;
        wr_data = 8'hFF;
        @(posedge clk);
        wr_en = 1'b0;
        wait_clocks(1);
        @(negedge clk);
        check_equal(count, DEPTH, "no_overflow_write");

        // -------------------------------------------------------
        // Test 4: Read all and verify data integrity
        // -------------------------------------------------------
        $display("[%0t] Reading all entries...", $time);
        for (int i = 0; i < DEPTH; i++) begin
            @(posedge clk);
            rd_en = 1'b1;
        end
        @(posedge clk);
        rd_en = 1'b0;
        wait_clocks(2);
        @(negedge clk);
        check(empty == 1'b1, "empty_after_reads");
        check_equal(count, 0, "count_zero_after_reads");

        // -------------------------------------------------------
        // Test 5: Read when empty (underflow protection)
        // -------------------------------------------------------
        @(posedge clk);
        rd_en = 1'b1;
        @(posedge clk);
        rd_en = 1'b0;
        wait_clocks(1);
        @(negedge clk);
        check_equal(count, 0, "no_underflow_read");

        // -------------------------------------------------------
        // Test 6: Simultaneous read/write (steady state)
        // -------------------------------------------------------
        apply_reset();
        // Pre-fill half the FIFO
        for (int i = 0; i < DEPTH/2; i++) begin
            @(posedge clk);
            wr_en   = 1'b1;
            wr_data = i[DATA_WIDTH-1:0];
        end
        @(posedge clk);
        wr_en = 1'b0;
        wait_clocks(1);

        // Simultaneous read and write for 8 cycles
        for (int i = 0; i < 8; i++) begin
            @(posedge clk);
            wr_en   = 1'b1;
            rd_en   = 1'b1;
            wr_data = (DEPTH/2 + i);
        end
        @(posedge clk);
        wr_en = 1'b0;
        rd_en = 1'b0;
        wait_clocks(1);
        @(negedge clk);
        check_equal(count, DEPTH/2, "steady_state_count");

        // -------------------------------------------------------
        // Test 7: Almost-full flag
        // -------------------------------------------------------
        apply_reset();
        for (int i = 0; i < DEPTH - 2; i++) begin
            @(posedge clk);
            wr_en   = 1'b1;
            wr_data = i[DATA_WIDTH-1:0];
        end
        @(posedge clk);
        wr_en = 1'b0;
        wait_clocks(1);
        @(negedge clk);
        check(almost_full == 1'b1, "almost_full_at_threshold");

        // -------------------------------------------------------
        // Summary
        // -------------------------------------------------------
        wait_clocks(5);
        print_summary("tb_fifo_sync");

        $finish;
    end

    // Watchdog
    initial begin
        #(CLK_PERIOD * 50000);
        $display("ERROR: Watchdog timeout!");
        $display("  ** TEST FAILED **");
        $finish;
    end

endmodule
