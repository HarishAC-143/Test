// =============================================================================
// Testbench for 32-Bit ALU
// Exercises all ALU operations with directed test vectors and random stimulus.
// =============================================================================

`timescale 1ns / 1ps

module tb_alu_32bit;

    parameter DATA_WIDTH = 32;

    logic [DATA_WIDTH-1:0] operand_a, operand_b;
    logic [3:0]            alu_op;
    logic [DATA_WIDTH-1:0] result;
    logic                  zero, carry, overflow, negative;

    alu_32bit #(.DATA_WIDTH(DATA_WIDTH)) dut (.*);

    // Expected values
    logic [DATA_WIDTH-1:0] expected_result;
    int pass_count = 0;
    int fail_count = 0;

    task automatic check(string op_name, logic [DATA_WIDTH-1:0] exp);
        #1;
        if (result !== exp) begin
            $display("[FAIL] %s: A=0x%08h B=0x%08h => Got 0x%08h, Expected 0x%08h",
                     op_name, operand_a, operand_b, result, exp);
            fail_count++;
        end else begin
            $display("[PASS] %s: A=0x%08h B=0x%08h => 0x%08h",
                     op_name, operand_a, operand_b, result);
            pass_count++;
        end
    endtask

    initial begin
        $display("========================================");
        $display("     ALU 32-Bit Testbench");
        $display("========================================");

        // Test ADD
        operand_a = 32'h0000_000A; operand_b = 32'h0000_0005; alu_op = 4'b0000;
        check("ADD", 32'h0000_000F);

        // Test SUB
        operand_a = 32'h0000_0010; operand_b = 32'h0000_0003; alu_op = 4'b0001;
        check("SUB", 32'h0000_000D);

        // Test AND
        operand_a = 32'hFF00_FF00; operand_b = 32'h0F0F_0F0F; alu_op = 4'b0010;
        check("AND", 32'h0F00_0F00);

        // Test OR
        operand_a = 32'hFF00_0000; operand_b = 32'h00FF_0000; alu_op = 4'b0011;
        check("OR", 32'hFFFF_0000);

        // Test XOR
        operand_a = 32'hAAAA_AAAA; operand_b = 32'h5555_5555; alu_op = 4'b0100;
        check("XOR", 32'hFFFF_FFFF);

        // Test SLL (shift left by 4)
        operand_a = 32'h0000_0001; operand_b = 32'h0000_0004; alu_op = 4'b0101;
        check("SLL", 32'h0000_0010);

        // Test SRL (shift right by 4)
        operand_a = 32'h8000_0000; operand_b = 32'h0000_0004; alu_op = 4'b0110;
        check("SRL", 32'h0800_0000);

        // Test SRA (arithmetic shift right)
        operand_a = 32'h8000_0000; operand_b = 32'h0000_0004; alu_op = 4'b0111;
        check("SRA", 32'hF800_0000);

        // Test SLT (signed)
        operand_a = 32'hFFFF_FFFF; operand_b = 32'h0000_0001; alu_op = 4'b1000;  // -1 < 1
        check("SLT", 32'h0000_0001);

        // Test SLTU (unsigned)
        operand_a = 32'h0000_0001; operand_b = 32'hFFFF_FFFF; alu_op = 4'b1001;  // 1 < 0xFFFFFFFF
        check("SLTU", 32'h0000_0001);

        // Test NOR
        operand_a = 32'hFF00_FF00; operand_b = 32'h00FF_00FF; alu_op = 4'b1010;
        check("NOR", 32'h0000_0000);

        // Test PASS
        operand_a = 32'hDEAD_BEEF; operand_b = 32'h0000_0000; alu_op = 4'b1111;
        check("PASS", 32'hDEAD_BEEF);

        // Test zero flag
        operand_a = 32'h0000_0005; operand_b = 32'h0000_0005; alu_op = 4'b0001;  // SUB => 0
        #1;
        if (zero !== 1'b1) begin
            $display("[FAIL] Zero flag not asserted for 5-5=0");
            fail_count++;
        end else begin
            $display("[PASS] Zero flag correctly asserted");
            pass_count++;
        end

        // Random test: ADD
        $display("\n--- Random ADD Tests ---");
        for (int i = 0; i < 20; i++) begin
            operand_a = $urandom;
            operand_b = $urandom;
            alu_op = 4'b0000;
            expected_result = operand_a + operand_b;
            check("ADD_RAND", expected_result);
        end

        $display("\n========================================");
        $display("  Results: %0d PASS, %0d FAIL", pass_count, fail_count);
        $display("========================================");
        $finish;
    end

endmodule
