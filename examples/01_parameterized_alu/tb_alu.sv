// Testbench for Parameterized ALU

module tb_alu;
    import alu_pkg::*;

    localparam int WIDTH = 32;

    logic [WIDTH-1:0] operand_a, operand_b;
    alu_op_t          alu_op;
    logic [WIDTH-1:0] result;
    alu_flags_t       flags;

    int error_count = 0;
    int test_count  = 0;

    alu #(.WIDTH(WIDTH)) dut (
        .operand_a(operand_a),
        .operand_b(operand_b),
        .alu_op(alu_op),
        .result(result),
        .flags(flags)
    );

    task automatic check(
        input string       name,
        input logic [WIDTH-1:0] expected
    );
        test_count++;
        #1;
        if (result !== expected) begin
            $error("[FAIL] %s: expected=0x%08h, got=0x%08h", name, expected, result);
            error_count++;
        end else begin
            $display("[PASS] %s: result=0x%08h", name, result);
        end
    endtask

    initial begin
        $display("=== ALU Testbench ===");
        $display("");

        // --- Arithmetic Tests ---
        operand_a = 32'h0000_000A; operand_b = 32'h0000_0005; alu_op = ALU_ADD;
        check("ADD: 10 + 5", 32'h0000_000F);

        operand_a = 32'hFFFF_FFFF; operand_b = 32'h0000_0001; alu_op = ALU_ADD;
        check("ADD: overflow", 32'h0000_0000);

        operand_a = 32'h0000_000A; operand_b = 32'h0000_0003; alu_op = ALU_SUB;
        check("SUB: 10 - 3", 32'h0000_0007);

        operand_a = 32'h0000_0003; operand_b = 32'h0000_000A; alu_op = ALU_SUB;
        check("SUB: 3 - 10 (negative)", 32'hFFFF_FFF9);

        // --- Logical Tests ---
        operand_a = 32'hFF00_FF00; operand_b = 32'h0F0F_0F0F; alu_op = ALU_AND;
        check("AND", 32'h0F00_0F00);

        operand_a = 32'hFF00_FF00; operand_b = 32'h0F0F_0F0F; alu_op = ALU_OR;
        check("OR", 32'hFF0F_FF0F);

        operand_a = 32'hFF00_FF00; operand_b = 32'h0F0F_0F0F; alu_op = ALU_XOR;
        check("XOR", 32'hF00F_F00F);

        operand_a = 32'hFF00_FF00; operand_b = 32'h0F0F_0F0F; alu_op = ALU_NOR;
        check("NOR", 32'h00F0_00F0);

        // --- Shift Tests ---
        operand_a = 32'h0000_0001; operand_b = 32'h0000_0004; alu_op = ALU_SLL;
        check("SLL: 1 << 4", 32'h0000_0010);

        operand_a = 32'h8000_0000; operand_b = 32'h0000_0004; alu_op = ALU_SRL;
        check("SRL: 0x80000000 >> 4", 32'h0800_0000);

        operand_a = 32'h8000_0000; operand_b = 32'h0000_0004; alu_op = ALU_SRA;
        check("SRA: 0x80000000 >>> 4", 32'hF800_0000);

        // --- Comparison Tests ---
        operand_a = 32'hFFFF_FFFF; operand_b = 32'h0000_0001; alu_op = ALU_SLT;
        check("SLT: -1 < 1 (signed)", 32'h0000_0001);

        operand_a = 32'hFFFF_FFFF; operand_b = 32'h0000_0001; alu_op = ALU_SLTU;
        check("SLTU: 0xFFFFFFFF < 1 (unsigned)", 32'h0000_0000);

        // --- Flag Tests ---
        operand_a = 32'h0000_0005; operand_b = 32'h0000_0005; alu_op = ALU_SUB;
        #1;
        test_count++;
        if (flags.zero !== 1'b1) begin
            $error("[FAIL] Zero flag: expected=1, got=%b", flags.zero);
            error_count++;
        end else begin
            $display("[PASS] Zero flag set correctly");
        end

        operand_a = 32'h7FFF_FFFF; operand_b = 32'h0000_0001; alu_op = ALU_ADD;
        #1;
        test_count++;
        if (flags.overflow !== 1'b1) begin
            $error("[FAIL] Overflow flag: expected=1, got=%b", flags.overflow);
            error_count++;
        end else begin
            $display("[PASS] Overflow flag set correctly");
        end

        // --- Summary ---
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
