// =============================================================================
// Testbench: Round-Robin Arbiter
// =============================================================================

module tb_round_robin_arbiter;

    parameter int NUM_REQUESTORS = 4;

    logic                      clk;
    logic                      rst_n;
    logic [NUM_REQUESTORS-1:0] req;
    logic [NUM_REQUESTORS-1:0] priority_req;
    logic [NUM_REQUESTORS-1:0] grant;
    logic                      grant_valid;

    round_robin_arbiter #(.NUM_REQUESTORS(NUM_REQUESTORS)) dut (.*);

    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        $dumpfile("arbiter_waves.vcd");
        $dumpvars(0, tb_round_robin_arbiter);

        rst_n        = 0;
        req          = 0;
        priority_req = 0;

        repeat(5) @(posedge clk);
        rst_n = 1;

        $display("\n=== Test 1: Single requestor ===");
        @(posedge clk); req = 4'b0001;
        @(posedge clk);
        $display("  req=%04b grant=%04b valid=%0b", req, grant, grant_valid);

        @(posedge clk); req = 4'b0100;
        @(posedge clk);
        $display("  req=%04b grant=%04b valid=%0b", req, grant, grant_valid);

        $display("\n=== Test 2: Multiple simultaneous requests (round-robin) ===");
        for (int cycle = 0; cycle < 8; cycle++) begin
            @(posedge clk); req = 4'b1111;
            @(posedge clk);
            $display("  Cycle %0d: grant=%04b", cycle, grant);
        end

        $display("\n=== Test 3: Priority override ===");
        @(posedge clk);
        req          = 4'b1111;
        priority_req = 4'b0010;
        @(posedge clk);
        $display("  Priority req=0010: grant=%04b (expected 0010)", grant);

        @(posedge clk);
        priority_req = 4'b1000;
        @(posedge clk);
        $display("  Priority req=1000: grant=%04b (expected 1000)", grant);

        @(posedge clk);
        priority_req = 0;

        $display("\n=== Test 4: No requests ===");
        @(posedge clk); req = 4'b0000;
        @(posedge clk);
        $display("  grant=%04b valid=%0b (expected 0000, 0)", grant, grant_valid);

        $display("\n=== Test 5: Alternating requests ===");
        for (int i = 0; i < 4; i++) begin
            @(posedge clk); req = 4'b0101;
            @(posedge clk);
            $display("  req=0101 grant=%04b", grant);
            @(posedge clk); req = 4'b1010;
            @(posedge clk);
            $display("  req=1010 grant=%04b", grant);
        end

        $display("\n=== All arbiter tests completed ===");
        $finish;
    end

    initial begin
        #10000;
        $display("ERROR: Testbench timed out!");
        $finish;
    end

endmodule
