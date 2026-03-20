// ============================================================================
// Reusable testbench template.
//
// Usage: Copy this file, replace DUT_MODULE with your module, and fill in
// the stimulus and checking sections.
// ============================================================================

module tb_template;

    // =========================================================================
    // Parameters — match your DUT
    // =========================================================================
    localparam int CLK_PERIOD = 10;   // ns
    localparam int TIMEOUT    = 100_000; // max simulation cycles

    // =========================================================================
    // DUT signals
    // =========================================================================
    logic clk;
    logic rst_n;
    // TODO: Add DUT-specific signals here
    // logic [7:0] data_in, data_out;
    // logic       valid, ready;

    // =========================================================================
    // DUT instantiation
    // =========================================================================
    // DUT_MODULE #(
    //     .PARAM (VALUE)
    // ) dut (
    //     .clk    (clk),
    //     .rst_n  (rst_n),
    //     ...
    // );

    // =========================================================================
    // Clock generation
    // =========================================================================
    initial clk = 1'b0;
    always #(CLK_PERIOD/2) clk = ~clk;

    // =========================================================================
    // Test control
    // =========================================================================
    int test_count  = 0;
    int pass_count  = 0;
    int fail_count  = 0;

    // Report helper
    task automatic check(
        input logic        condition,
        input string       test_name
    );
        test_count++;
        if (condition) begin
            pass_count++;
            $display("[%0t] PASS: %s", $time, test_name);
        end else begin
            fail_count++;
            $display("[%0t] FAIL: %s", $time, test_name);
        end
    endtask

    // =========================================================================
    // Main test sequence
    // =========================================================================
    initial begin
        $display("============================================");
        $display(" Testbench: %m");
        $display("============================================\n");

        // Reset
        rst_n = 1'b0;
        // TODO: Initialize all DUT inputs to known values
        repeat (5) @(posedge clk);
        rst_n = 1'b1;
        @(posedge clk);

        // --------------------------------------------------
        // Test 1: Basic functionality
        // --------------------------------------------------
        $display("--- Test 1: Basic functionality ---");
        // TODO: Apply stimulus
        // TODO: Wait for response
        // check(data_out === expected, "Test 1 description");

        // --------------------------------------------------
        // Test 2: Edge cases
        // --------------------------------------------------
        $display("--- Test 2: Edge cases ---");
        // TODO: Test boundary conditions

        // --------------------------------------------------
        // Test 3: Random stimulus
        // --------------------------------------------------
        $display("--- Test 3: Random stimulus ---");
        // for (int i = 0; i < 100; i++) begin
        //     data_in = $urandom;
        //     @(posedge clk);
        //     check(data_out === expected, $sformatf("Random test %0d", i));
        // end

        // --------------------------------------------------
        // Summary
        // --------------------------------------------------
        $display("\n============================================");
        $display(" Results: %0d/%0d passed", pass_count, test_count);
        $display("============================================");

        if (fail_count == 0)
            $display("*** ALL TESTS PASSED ***\n");
        else
            $display("*** %0d TESTS FAILED ***\n", fail_count);

        $finish;
    end

    // =========================================================================
    // Timeout watchdog
    // =========================================================================
    initial begin
        #(CLK_PERIOD * TIMEOUT);
        $display("ERROR: Simulation timeout after %0d cycles", TIMEOUT);
        $finish;
    end

    // =========================================================================
    // Waveform dump
    // =========================================================================
    initial begin
        $dumpfile("tb_template.vcd");
        $dumpvars(0, tb_template);
    end

endmodule
