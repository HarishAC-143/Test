// Testbench: Vending Machine Mealy FSM

`timescale 1ns / 1ps

module tb_vending_machine;

    parameter CLK_PERIOD = 10;

    logic clk, rst_n;
    logic nickel, dime;
    logic dispense, change;

    vending_machine_mealy u_dut (.*);

    initial clk = 1'b0;
    always #(CLK_PERIOD/2) clk = ~clk;

    task automatic insert_coin(input logic is_dime);
        @(posedge clk);
        if (is_dime) begin
            dime = 1'b1;
            nickel = 1'b0;
        end else begin
            nickel = 1'b1;
            dime = 1'b0;
        end
        @(posedge clk);
        nickel = 1'b0;
        dime   = 1'b0;
    endtask

    initial begin
        $display("=== VENDING MACHINE Testbench ===");

        rst_n  = 1'b0;
        nickel = 1'b0;
        dime   = 1'b0;
        repeat (3) @(posedge clk);
        rst_n = 1'b1;
        @(posedge clk);

        // Scenario 1: Three nickels (5 + 5 + 5 = 15)
        $display("  Scenario 1: 3 nickels");
        insert_coin(0);  // 5c
        #1; assert (!dispense) else $error("Premature dispense after 5c");
        insert_coin(0);  // 10c
        #1; assert (!dispense) else $error("Premature dispense after 10c");
        insert_coin(0);  // 15c -> dispense
        #1; assert (dispense && !change)
            else $error("Expected dispense=1, change=0 at 15c");
        $display("    Dispensed, no change  PASS");

        // Scenario 2: Nickel + Dime (5 + 10 = 15)
        @(posedge clk);
        $display("  Scenario 2: nickel + dime");
        insert_coin(0);  // 5c
        insert_coin(1);  // 5 + 10 = 15c -> dispense
        #1; assert (dispense && !change)
            else $error("Expected dispense=1, change=0");
        $display("    Dispensed, no change  PASS");

        // Scenario 3: Dime + Nickel (10 + 5 = 15)
        @(posedge clk);
        $display("  Scenario 3: dime + nickel");
        insert_coin(1);  // 10c
        insert_coin(0);  // 10 + 5 = 15c -> dispense
        #1; assert (dispense && !change)
            else $error("Expected dispense=1, change=0");
        $display("    Dispensed, no change  PASS");

        // Scenario 4: Two dimes (10 + 10 = 20) -> dispense + change
        @(posedge clk);
        $display("  Scenario 4: 2 dimes (overpay)");
        insert_coin(1);  // 10c
        insert_coin(1);  // 10 + 10 = 20c -> dispense + change
        #1; assert (dispense && change)
            else $error("Expected dispense=1, change=1");
        $display("    Dispensed with change  PASS");

        $display("=== VENDING MACHINE All Tests Passed ===");
        $finish;
    end

    initial begin
        #100000;
        $error("Simulation timeout!");
        $finish;
    end

endmodule
