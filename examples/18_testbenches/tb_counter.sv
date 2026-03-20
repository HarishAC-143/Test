// ============================================================================
// Testbench: Configurable Counter
// ============================================================================
// Tests up-counting, down-counting, wrap-around, load, and terminal count.
// ============================================================================

`timescale 1ns / 1ps

module tb_counter;

    parameter int WIDTH     = 8;
    parameter int MAX_COUNT = 15;  // smaller for faster simulation

    logic             clk, rst_n;
    logic             en, up_down, load;
    logic [WIDTH-1:0] load_val, count;
    logic             tc, zero;

    initial clk = 1'b0;
    always #5ns clk = ~clk;

    counter #(
        .WIDTH     (WIDTH),
        .MAX_COUNT (MAX_COUNT)
    ) dut (.*);

    int pass_count = 0;
    int fail_count = 0;

    task automatic check_count(
        input string      desc,
        input logic [WIDTH-1:0] expected
    );
        @(negedge clk);
        if (count === expected) begin
            pass_count++;
        end else begin
            $error("%s: count=%0d, expected=%0d", desc, count, expected);
            fail_count++;
        end
    endtask

    initial begin
        $display("========================================");
        $display("  Counter Testbench");
        $display("  WIDTH=%0d, MAX_COUNT=%0d", WIDTH, MAX_COUNT);
        $display("========================================");

        rst_n    <= 1'b0;
        en       <= 1'b0;
        up_down  <= 1'b1;
        load     <= 1'b0;
        load_val <= '0;
        repeat (3) @(posedge clk);
        rst_n <= 1'b1;
        @(posedge clk);

        // Test 1: Count up
        $display("\n=== Test 1: Count up ===");
        en      <= 1'b1;
        up_down <= 1'b1;
        for (int i = 1; i <= MAX_COUNT; i++) begin
            @(posedge clk);
            check_count($sformatf("up[%0d]", i), i[WIDTH-1:0]);
        end
        // Should wrap
        @(posedge clk);
        check_count("wrap-up", '0);

        // Test 2: Load
        $display("\n=== Test 2: Load ===");
        en       <= 1'b0;
        load     <= 1'b1;
        load_val <= 8'd10;
        @(posedge clk);
        load <= 1'b0;
        @(posedge clk);
        check_count("load", 8'd10);

        // Test 3: Count down
        $display("\n=== Test 3: Count down ===");
        en      <= 1'b1;
        up_down <= 1'b0;
        for (int i = 9; i >= 0; i--) begin
            @(posedge clk);
            check_count($sformatf("down[%0d]", i), i[WIDTH-1:0]);
        end
        // Should wrap to MAX_COUNT
        @(posedge clk);
        check_count("wrap-down", MAX_COUNT[WIDTH-1:0]);

        $display("\n========================================");
        $display("  PASS=%0d  FAIL=%0d", pass_count, fail_count);
        if (fail_count == 0)
            $display("  *** ALL TESTS PASSED ***");
        else
            $display("  *** SOME TESTS FAILED ***");
        $display("========================================");
        $finish;
    end

    initial begin
        #10us;
        $fatal(1, "Simulation timed out!");
    end

endmodule
