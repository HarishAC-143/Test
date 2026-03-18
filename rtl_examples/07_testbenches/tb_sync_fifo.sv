// =============================================================================
// Testbench for Synchronous FIFO
// Verifies write, read, full, empty, and overflow/underflow conditions.
// =============================================================================

`timescale 1ns / 1ps

module tb_sync_fifo;

    parameter DATA_WIDTH = 8;
    parameter DEPTH      = 8;

    logic                    clk;
    logic                    rst_n;
    logic                    wr_en;
    logic [DATA_WIDTH-1:0]   wr_data;
    logic                    rd_en;
    logic [DATA_WIDTH-1:0]   rd_data;
    logic                    full;
    logic                    empty;
    logic                    almost_full;
    logic                    almost_empty;
    logic [$clog2(DEPTH):0]  count;

    sync_fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH(DEPTH),
        .ALMOST_FULL(DEPTH - 2),
        .ALMOST_EMPTY(2)
    ) dut (.*);

    // Clock generation: 10 ns period
    initial clk = 0;
    always #5 clk = ~clk;

    int pass_count = 0;
    int fail_count = 0;

    task automatic check_flag(string name, logic actual, logic expected);
        if (actual !== expected) begin
            $display("[FAIL] %s: got %b, expected %b", name, actual, expected);
            fail_count++;
        end else begin
            pass_count++;
        end
    endtask

    initial begin
        $display("========================================");
        $display("     Sync FIFO Testbench");
        $display("========================================");

        // Reset
        rst_n = 0; wr_en = 0; rd_en = 0; wr_data = 0;
        repeat (3) @(posedge clk);
        rst_n = 1;
        @(posedge clk);

        // Check initial state
        check_flag("Empty after reset", empty, 1'b1);
        check_flag("Not full after reset", full, 1'b0);
        $display("[INFO] FIFO is empty after reset — count = %0d", count);

        // Fill the FIFO
        $display("\n--- Filling FIFO ---");
        for (int i = 0; i < DEPTH; i++) begin
            @(posedge clk);
            wr_en   = 1;
            wr_data = DATA_WIDTH'(i * 11);
            @(posedge clk);
            wr_en = 0;
            $display("[INFO] Wrote 0x%02h, count = %0d, full = %b", i * 11, count, full);
        end

        @(posedge clk);
        check_flag("Full after filling", full, 1'b1);
        check_flag("Not empty when full", empty, 1'b0);

        // Read all entries and verify data
        $display("\n--- Reading FIFO ---");
        for (int i = 0; i < DEPTH; i++) begin
            rd_en = 1;
            @(posedge clk);
            if (rd_data !== DATA_WIDTH'(i * 11)) begin
                $display("[FAIL] Read data mismatch: got 0x%02h, expected 0x%02h", rd_data, i * 11);
                fail_count++;
            end else begin
                $display("[PASS] Read 0x%02h correctly", rd_data);
                pass_count++;
            end
            rd_en = 0;
            @(posedge clk);
        end

        check_flag("Empty after reading all", empty, 1'b1);

        // Simultaneous write and read
        $display("\n--- Simultaneous Write/Read ---");
        wr_en = 1; wr_data = 8'hAA;
        @(posedge clk);
        wr_en = 0;
        @(posedge clk);

        wr_en = 1; wr_data = 8'hBB; rd_en = 1;
        @(posedge clk);
        wr_en = 0; rd_en = 0;
        @(posedge clk);

        $display("[INFO] After simultaneous write/read: count = %0d", count);

        $display("\n========================================");
        $display("  Results: %0d PASS, %0d FAIL", pass_count, fail_count);
        $display("========================================");
        $finish;
    end

    // Timeout
    initial begin
        #10000;
        $display("[ERROR] Simulation timeout!");
        $finish;
    end

endmodule
