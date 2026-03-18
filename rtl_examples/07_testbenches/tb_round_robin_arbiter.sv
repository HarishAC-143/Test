// =============================================================================
// Testbench for Round-Robin Arbiter
// Verifies fair grant rotation among competing requestors.
// =============================================================================

`timescale 1ns / 1ps

module tb_round_robin_arbiter;

    parameter NUM_REQ = 4;

    logic                  clk;
    logic                  rst_n;
    logic [NUM_REQ-1:0]    request;
    logic [NUM_REQ-1:0]    grant;
    logic                  valid;

    round_robin_arbiter #(.NUM_REQ(NUM_REQ)) dut (.*);

    initial clk = 0;
    always #5 clk = ~clk;

    int grant_count [NUM_REQ];

    initial begin
        $display("========================================");
        $display("  Round-Robin Arbiter Testbench");
        $display("========================================");

        for (int i = 0; i < NUM_REQ; i++) grant_count[i] = 0;

        rst_n   = 0;
        request = 0;
        repeat (3) @(posedge clk);
        rst_n = 1;

        // All requestors competing simultaneously
        $display("\n--- All 4 requestors active ---");
        request = 4'b1111;
        for (int cycle = 0; cycle < 16; cycle++) begin
            @(posedge clk); #1;
            $display("Cycle %2d: request=%b  grant=%b  valid=%b",
                     cycle, request, grant, valid);
            for (int i = 0; i < NUM_REQ; i++)
                if (grant[i]) grant_count[i]++;
        end

        $display("\nGrant distribution (should be ~4 each):");
        for (int i = 0; i < NUM_REQ; i++)
            $display("  Requestor %0d: %0d grants", i, grant_count[i]);

        // Single requestor
        $display("\n--- Single requestor ---");
        request = 4'b0010;
        @(posedge clk); #1;
        $display("request=%b  grant=%b  valid=%b (expect grant[1])", request, grant, valid);

        // Two requestors
        $display("\n--- Two requestors ---");
        for (int i = 0; i < NUM_REQ; i++) grant_count[i] = 0;
        request = 4'b1010;
        for (int cycle = 0; cycle < 8; cycle++) begin
            @(posedge clk); #1;
            for (int i = 0; i < NUM_REQ; i++)
                if (grant[i]) grant_count[i]++;
        end
        $display("Grant distribution for req 1 & 3:");
        $display("  Requestor 1: %0d grants", grant_count[1]);
        $display("  Requestor 3: %0d grants", grant_count[3]);

        // No requests
        $display("\n--- No requestors ---");
        request = 4'b0000;
        @(posedge clk); #1;
        $display("request=%b  grant=%b  valid=%b (expect valid=0)", request, grant, valid);

        $display("\n========================================");
        $display("  Testbench complete");
        $display("========================================");
        $finish;
    end

endmodule
