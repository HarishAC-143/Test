// Testbench for Round-Robin Arbiter

module tb_round_robin_arbiter;

    localparam int N = 4;

    logic         clk;
    logic         rst_n;
    logic [N-1:0] req;
    logic         lock;
    logic [N-1:0] grant;
    logic         valid;

    int error_count = 0;
    int test_count  = 0;

    round_robin_arbiter #(.N(N)) dut (.*);

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    function automatic string grant_str(input logic [N-1:0] g);
        for (int i = 0; i < N; i++) begin
            if (g[i]) return $sformatf("Port %0d", i);
        end
        return "None";
    endfunction

    task automatic check_grant(input string name, input logic [N-1:0] expected);
        test_count++;
        @(posedge clk);
        #1;
        if (grant !== expected) begin
            $error("[FAIL] %s: expected grant=%b, got=%b", name, expected, grant);
            error_count++;
        end else begin
            $display("[PASS] %s: grant=%s (%b)", name, grant_str(grant), grant);
        end
    endtask

    initial begin
        $display("=== Round-Robin Arbiter Testbench ===");
        $display("");

        rst_n = 0;
        req   = '0;
        lock  = 0;

        repeat (3) @(posedge clk);
        rst_n = 1;
        @(posedge clk);

        // Test 1: Single requestor
        $display("[Test 1] Single requestor");
        req = 4'b0001;
        check_grant("Req[0] only", 4'b0001);

        req = 4'b0000;
        @(posedge clk);

        // Test 2: Round-robin fairness
        $display("");
        $display("[Test 2] Round-robin fairness with all 4 requesting");
        req = 4'b1111;  // All request simultaneously

        // Should grant in round-robin order
        @(posedge clk); #1;
        $display("  Grant cycle 1: %s", grant_str(grant));
        @(posedge clk); #1;
        $display("  Grant cycle 2: %s", grant_str(grant));
        @(posedge clk); #1;
        $display("  Grant cycle 3: %s", grant_str(grant));
        @(posedge clk); #1;
        $display("  Grant cycle 4: %s", grant_str(grant));
        // After 4 cycles, it should wrap around
        @(posedge clk); #1;
        $display("  Grant cycle 5 (wrap): %s", grant_str(grant));

        test_count++;
        if (valid !== 1'b1) begin
            $error("[FAIL] Valid should be asserted");
            error_count++;
        end else begin
            $display("[PASS] All requestors served");
        end

        // Test 3: Subset of requestors
        $display("");
        $display("[Test 3] Subset of requestors (0 and 2)");
        req = 4'b0101;
        @(posedge clk); #1;
        $display("  Grant cycle 1: %s", grant_str(grant));
        @(posedge clk); #1;
        $display("  Grant cycle 2: %s", grant_str(grant));
        @(posedge clk); #1;
        $display("  Grant cycle 3: %s", grant_str(grant));

        // Test 4: Lock signal (burst mode)
        $display("");
        $display("[Test 4] Lock signal holds grant");
        req  = 4'b1111;
        lock = 0;
        @(posedge clk); #1;
        automatic logic [N-1:0] locked_grant = grant;
        $display("  Initial grant: %s", grant_str(grant));

        lock = 1;
        repeat (4) begin
            @(posedge clk); #1;
            test_count++;
            if (grant !== locked_grant) begin
                $error("[FAIL] Grant changed during lock");
                error_count++;
            end
        end
        $display("[PASS] Grant held steady during lock");

        lock = 0;
        @(posedge clk); #1;
        $display("  After unlock: %s (should advance)", grant_str(grant));

        // Test 5: No requests
        $display("");
        $display("[Test 5] No requests");
        req = 4'b0000;
        @(posedge clk); @(posedge clk); #1;
        test_count++;
        if (valid !== 1'b0) begin
            $error("[FAIL] Valid should be deasserted with no requests");
            error_count++;
        end else begin
            $display("[PASS] No grant when no requests");
        end

        $display("");
        $display("=== Results: %0d/%0d tests passed ===",
                 test_count - error_count, test_count);
        if (error_count == 0)
            $display("ALL TESTS PASSED");
        else
            $display("FAILURES DETECTED");

        $finish;
    end

endmodule
