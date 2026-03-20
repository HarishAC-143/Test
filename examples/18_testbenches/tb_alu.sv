// ============================================================================
// Testbench: ALU
// ============================================================================
// Self-checking testbench for the parameterized ALU module.
// Tests all operations with known input/output pairs.
// ============================================================================

`timescale 1ns / 1ps

module tb_alu;

    parameter int WIDTH = 32;

    logic [WIDTH-1:0] a, b, result;
    logic [3:0]       op;
    logic             zero, carry, overflow;

    alu #(.WIDTH(WIDTH)) dut (.*);

    int pass_count = 0;
    int fail_count = 0;

    task automatic check(
        input string      op_name,
        input logic [WIDTH-1:0] expected,
        input logic             exp_zero
    );
        #1;
        if (result === expected && zero === exp_zero) begin
            pass_count++;
        end else begin
            $error("%s: a=0x%0h b=0x%0h => got 0x%0h (zero=%b), expected 0x%0h (zero=%b)",
                   op_name, a, b, result, zero, expected, exp_zero);
            fail_count++;
        end
    endtask

    initial begin
        $display("========================================");
        $display("  ALU Testbench (WIDTH=%0d)", WIDTH);
        $display("========================================");

        // ADD
        a = 32'h0000_000A; b = 32'h0000_0005; op = 4'h0;
        check("ADD", 32'h0000_000F, 1'b0);

        // ADD resulting in zero
        a = 32'h0000_0000; b = 32'h0000_0000; op = 4'h0;
        check("ADD(zero)", 32'h0000_0000, 1'b1);

        // SUB
        a = 32'h0000_000A; b = 32'h0000_0005; op = 4'h1;
        check("SUB", 32'h0000_0005, 1'b0);

        // AND
        a = 32'hFF00_FF00; b = 32'h0F0F_0F0F; op = 4'h2;
        check("AND", 32'h0F00_0F00, 1'b0);

        // OR
        a = 32'hFF00_0000; b = 32'h00FF_0000; op = 4'h3;
        check("OR", 32'hFFFF_0000, 1'b0);

        // XOR
        a = 32'hAAAA_AAAA; b = 32'h5555_5555; op = 4'h4;
        check("XOR", 32'hFFFF_FFFF, 1'b0);

        // NOT
        a = 32'hFFFF_FFFF; b = '0; op = 4'h5;
        check("NOT", 32'h0000_0000, 1'b1);

        // SLL
        a = 32'h0000_0001; b = 32'h0000_0004; op = 4'h6;
        check("SLL", 32'h0000_0010, 1'b0);

        // SRL
        a = 32'h8000_0000; b = 32'h0000_001F; op = 4'h7;
        check("SRL", 32'h0000_0001, 1'b0);

        // SRA (arithmetic shift — preserves sign)
        a = 32'h8000_0000; b = 32'h0000_001F; op = 4'h8;
        check("SRA", 32'hFFFF_FFFF, 1'b0);

        // SLT (signed)
        a = 32'hFFFF_FFFF; b = 32'h0000_0001; op = 4'h9;  // -1 < 1
        check("SLT", 32'h0000_0001, 1'b0);

        // SLTU (unsigned)
        a = 32'h0000_0001; b = 32'hFFFF_FFFF; op = 4'hA;  // 1 < 0xFFFFFFFF
        check("SLTU", 32'h0000_0001, 1'b0);

        $display("\n========================================");
        $display("  PASS=%0d  FAIL=%0d", pass_count, fail_count);
        if (fail_count == 0)
            $display("  *** ALL TESTS PASSED ***");
        else
            $display("  *** SOME TESTS FAILED ***");
        $display("========================================");
        $finish;
    end

endmodule
