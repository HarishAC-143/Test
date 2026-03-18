// Self-checking testbench for the parameterized counter module.
// Tests: reset, count up/down, load, overflow, underflow, saturation, enable gating.

`timescale 1ns / 1ps

module tb_counter;

    import tb_pkg::*;

    // Parameters under test
    localparam int WIDTH = 8;
    localparam int CLK_PERIOD = 10;

    // Signals
    logic             clk;
    logic             rst_n;
    logic             enable;
    logic             load;
    logic             up_down;
    logic [WIDTH-1:0] load_val;
    logic [WIDTH-1:0] count;
    logic             overflow;
    logic             underflow;

    // DUT instantiation (wrap-around mode)
    counter #(
        .WIDTH    (WIDTH),
        .SATURATE (1'b0)
    ) dut (
        .clk       (clk),
        .rst_n     (rst_n),
        .enable    (enable),
        .load      (load),
        .up_down   (up_down),
        .load_val  (load_val),
        .count     (count),
        .overflow  (overflow),
        .underflow (underflow)
    );

    // Clock generation
    initial clk = 1'b0;
    always #(CLK_PERIOD/2) clk = ~clk;

    // Helper tasks
    task automatic wait_clocks(input int n);
        repeat (n) @(posedge clk);
    endtask

    task automatic apply_reset();
        rst_n = 1'b0;
        enable = 1'b0;
        load = 1'b0;
        up_down = 1'b1;
        load_val = '0;
        wait_clocks(5);
        rst_n = 1'b1;
        wait_clocks(2);
    endtask

    // Test procedures
    initial begin
        reset_counters();
        $display("=== Counter Testbench Start ===");

        // -------------------------------------------------------
        // Test 1: Reset behavior
        // -------------------------------------------------------
        apply_reset();
        check_equal(count, 0, "reset_value");
        check(overflow == 1'b0, "reset_overflow");
        check(underflow == 1'b0, "reset_underflow");

        // -------------------------------------------------------
        // Test 2: Count up
        // -------------------------------------------------------
        enable  = 1'b1;
        up_down = 1'b1;
        wait_clocks(10);
        @(negedge clk);
        check_equal(count, 10, "count_up_10");

        // -------------------------------------------------------
        // Test 3: Count down
        // -------------------------------------------------------
        apply_reset();
        load     = 1'b1;
        load_val = 8'd20;
        @(posedge clk);
        #1;
        load    = 1'b0;
        enable  = 1'b1;
        up_down = 1'b0;
        wait_clocks(5);
        @(negedge clk);
        check_equal(count, 15, "count_down_from_20");

        // -------------------------------------------------------
        // Test 4: Parallel load
        // -------------------------------------------------------
        apply_reset();
        load     = 1'b1;
        load_val = 8'd100;
        @(posedge clk);
        #1;
        @(negedge clk);
        check_equal(count, 100, "parallel_load");
        load = 1'b0;

        // -------------------------------------------------------
        // Test 5: Overflow (wrap-around mode)
        // -------------------------------------------------------
        apply_reset();
        load     = 1'b1;
        load_val = 8'd254;
        @(posedge clk);
        #1;
        load    = 1'b0;
        enable  = 1'b1;
        up_down = 1'b1;

        // count=254 → 255 (no overflow yet)
        wait_clocks(1);
        @(negedge clk);
        check_equal(count, 255, "pre_overflow");
        check(overflow == 1'b0, "no_overflow_at_255");

        // count=255 → 0 (overflow)
        wait_clocks(1);
        @(negedge clk);
        check_equal(count, 0, "wrap_around");
        check(overflow == 1'b1, "overflow_flag");

        // Overflow clears on next cycle
        wait_clocks(1);
        @(negedge clk);
        check(overflow == 1'b0, "overflow_clears");

        // -------------------------------------------------------
        // Test 6: Underflow (wrap-around mode)
        // -------------------------------------------------------
        apply_reset();
        load     = 1'b1;
        load_val = 8'd1;
        @(posedge clk);
        #1;
        load    = 1'b0;
        enable  = 1'b1;
        up_down = 1'b0;

        // count=1 → 0 (no underflow)
        wait_clocks(1);
        @(negedge clk);
        check_equal(count, 0, "pre_underflow");
        check(underflow == 1'b0, "no_underflow_at_0");

        // count=0 → 255 (underflow)
        wait_clocks(1);
        @(negedge clk);
        check_equal(count, 255, "wrap_around_down");
        check(underflow == 1'b1, "underflow_flag");

        // -------------------------------------------------------
        // Test 7: Enable gating
        // -------------------------------------------------------
        apply_reset();
        enable  = 1'b0;
        up_down = 1'b1;
        wait_clocks(10);
        @(negedge clk);
        check_equal(count, 0, "disabled_no_count");

        // -------------------------------------------------------
        // Summary
        // -------------------------------------------------------
        wait_clocks(2);
        print_summary("tb_counter");

        $finish;
    end

    // Watchdog timer
    initial begin
        #(CLK_PERIOD * 10000);
        $display("ERROR: Watchdog timeout!");
        $display("  ** TEST FAILED **");
        $finish;
    end

endmodule
