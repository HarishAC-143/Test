// Self-checking testbench for the configurable counter.

module counter_tb;

    localparam int WIDTH     = 4;
    localparam int MAX_COUNT = 15;
    localparam int CLK_PERIOD = 10;

    logic             clk, rst_n, enable, up_down, load;
    logic [WIDTH-1:0] load_val, count;
    logic             wrap;

    counter #(
        .WIDTH     (WIDTH),
        .MAX_COUNT (MAX_COUNT)
    ) dut (.*);

    // Clock generation
    initial clk = 1'b0;
    always #(CLK_PERIOD/2) clk = ~clk;

    int error_count = 0;

    task automatic check(input logic [WIDTH-1:0] expected, input string msg);
        if (count !== expected) begin
            $display("FAIL [%0t]: %s — got %0d, expected %0d", $time, msg, count, expected);
            error_count++;
        end
    endtask

    initial begin
        $display("=== Counter Testbench (WIDTH=%0d, MAX=%0d) ===", WIDTH, MAX_COUNT);

        // Reset
        rst_n   = 1'b0;
        enable  = 1'b0;
        up_down = 1'b1;
        load    = 1'b0;
        load_val = '0;
        repeat (3) @(posedge clk);
        rst_n = 1'b1;
        @(posedge clk);
        check(4'd0, "after reset");

        // Count up
        enable = 1'b1;
        for (int i = 1; i <= MAX_COUNT; i++) begin
            @(posedge clk);
            check(WIDTH'(i), $sformatf("count up to %0d", i));
        end

        // Wrap around
        @(posedge clk);
        check(4'd0, "wrap around to 0");

        // Parallel load
        enable  = 1'b0;
        load    = 1'b1;
        load_val = 4'd10;
        @(posedge clk);
        load = 1'b0;
        @(posedge clk);
        check(4'd10, "after load 10");

        // Count down
        enable  = 1'b1;
        up_down = 1'b0;
        repeat (5) @(posedge clk);
        check(4'd5, "count down to 5");

        // Count down to wrap
        repeat (6) @(posedge clk);
        check(4'd15, "wrap from 0 to MAX");

        // Disable
        enable = 1'b0;
        @(posedge clk);
        @(posedge clk);
        logic [WIDTH-1:0] held = count;
        @(posedge clk);
        check(held, "held when disabled");

        if (error_count == 0)
            $display("\n*** ALL TESTS PASSED ***");
        else
            $display("\n*** %0d TESTS FAILED ***", error_count);

        $finish;
    end

    initial begin
        $dumpfile("counter_tb.vcd");
        $dumpvars(0, counter_tb);
    end

endmodule
