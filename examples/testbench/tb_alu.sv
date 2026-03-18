// Self-checking testbench for the parameterized ALU.
// Tests: all arithmetic/logical/shift operations, flags, boundary values,
//        and constrained-random stimulus.

`timescale 1ns / 1ps

module tb_alu;

    import tb_pkg::*;

    localparam int WIDTH = 16;

    // Operation codes (must match alu.sv)
    localparam logic [3:0] OP_ADD  = 4'b0000;
    localparam logic [3:0] OP_SUB  = 4'b0001;
    localparam logic [3:0] OP_MUL  = 4'b0010;
    localparam logic [3:0] OP_AND  = 4'b0011;
    localparam logic [3:0] OP_OR   = 4'b0100;
    localparam logic [3:0] OP_XOR  = 4'b0101;
    localparam logic [3:0] OP_NOT  = 4'b0110;
    localparam logic [3:0] OP_SLL  = 4'b0111;
    localparam logic [3:0] OP_SRL  = 4'b1000;
    localparam logic [3:0] OP_SRA  = 4'b1001;
    localparam logic [3:0] OP_PASS = 4'b1010;
    localparam logic [3:0] OP_CMP  = 4'b1011;

    logic [WIDTH-1:0] operand_a;
    logic [WIDTH-1:0] operand_b;
    logic [3:0]       operation;
    logic [WIDTH-1:0] result;
    logic             zero_flag;
    logic             carry_flag;
    logic             overflow_flag;

    alu #(.WIDTH(WIDTH)) dut (
        .operand_a     (operand_a),
        .operand_b     (operand_b),
        .operation     (operation),
        .result        (result),
        .zero_flag     (zero_flag),
        .carry_flag    (carry_flag),
        .overflow_flag (overflow_flag)
    );

    // Combinational delay for evaluation
    localparam int EVAL_DELAY = 5;

    task automatic eval();
        #EVAL_DELAY;
    endtask

    // Reference model for verification
    function automatic logic [WIDTH-1:0] ref_result(
        input logic [WIDTH-1:0] a,
        input logic [WIDTH-1:0] b,
        input logic [3:0]       op
    );
        case (op)
            OP_ADD:  return a + b;
            OP_SUB:  return a - b;
            OP_MUL:  return (a * b);
            OP_AND:  return a & b;
            OP_OR:   return a | b;
            OP_XOR:  return a ^ b;
            OP_NOT:  return ~a;
            OP_SLL:  return a << b[$clog2(WIDTH)-1:0];
            OP_SRL:  return a >> b[$clog2(WIDTH)-1:0];
            OP_SRA:  return $signed(a) >>> b[$clog2(WIDTH)-1:0];
            OP_PASS: return a;
            OP_CMP:  return a - b;
            default: return '0;
        endcase
    endfunction

    function automatic string op_name(input logic [3:0] op);
        case (op)
            OP_ADD:  return "ADD";
            OP_SUB:  return "SUB";
            OP_MUL:  return "MUL";
            OP_AND:  return "AND";
            OP_OR:   return "OR";
            OP_XOR:  return "XOR";
            OP_NOT:  return "NOT";
            OP_SLL:  return "SLL";
            OP_SRL:  return "SRL";
            OP_SRA:  return "SRA";
            OP_PASS: return "PASS";
            OP_CMP:  return "CMP";
            default: return "???";
        endcase
    endfunction

    initial begin
        reset_counters();
        $display("=== ALU Testbench Start ===");

        // -------------------------------------------------------
        // Test 1: Addition
        // -------------------------------------------------------
        operand_a = 16'd100;
        operand_b = 16'd200;
        operation = OP_ADD;
        eval();
        check_equal(result, 16'd300, "add_100_200");

        // Addition with carry
        operand_a = 16'hFFFF;
        operand_b = 16'd1;
        operation = OP_ADD;
        eval();
        check_equal(result, 16'd0, "add_overflow_wrap");
        check(carry_flag == 1'b1, "add_carry_flag");
        check(zero_flag == 1'b1, "add_zero_flag");

        // -------------------------------------------------------
        // Test 2: Subtraction
        // -------------------------------------------------------
        operand_a = 16'd500;
        operand_b = 16'd300;
        operation = OP_SUB;
        eval();
        check_equal(result, 16'd200, "sub_500_300");

        operand_a = 16'd0;
        operand_b = 16'd1;
        operation = OP_SUB;
        eval();
        check_equal(result, 16'hFFFF, "sub_underflow");
        check(carry_flag == 1'b1, "sub_borrow_flag");

        // -------------------------------------------------------
        // Test 3: Multiplication
        // -------------------------------------------------------
        operand_a = 16'd25;
        operand_b = 16'd4;
        operation = OP_MUL;
        eval();
        check_equal(result, 16'd100, "mul_25_4");

        operand_a = 16'd256;
        operand_b = 16'd256;
        operation = OP_MUL;
        eval();
        check_equal(result, 16'd0, "mul_256_256_lower16");

        // -------------------------------------------------------
        // Test 4: Logical AND
        // -------------------------------------------------------
        operand_a = 16'hFF00;
        operand_b = 16'h0F0F;
        operation = OP_AND;
        eval();
        check_equal(result, 16'h0F00, "and_ff00_0f0f");

        // -------------------------------------------------------
        // Test 5: Logical OR
        // -------------------------------------------------------
        operand_a = 16'hFF00;
        operand_b = 16'h00FF;
        operation = OP_OR;
        eval();
        check_equal(result, 16'hFFFF, "or_ff00_00ff");

        // -------------------------------------------------------
        // Test 6: Logical XOR
        // -------------------------------------------------------
        operand_a = 16'hAAAA;
        operand_b = 16'h5555;
        operation = OP_XOR;
        eval();
        check_equal(result, 16'hFFFF, "xor_aaaa_5555");

        operand_a = 16'hAAAA;
        operand_b = 16'hAAAA;
        operation = OP_XOR;
        eval();
        check_equal(result, 16'h0000, "xor_same_value");
        check(zero_flag == 1'b1, "xor_zero_flag");

        // -------------------------------------------------------
        // Test 7: Bitwise NOT
        // -------------------------------------------------------
        operand_a = 16'hFF00;
        operand_b = 16'd0;
        operation = OP_NOT;
        eval();
        check_equal(result, 16'h00FF, "not_ff00");

        // -------------------------------------------------------
        // Test 8: Shift left logical
        // -------------------------------------------------------
        operand_a = 16'h0001;
        operand_b = 16'd4;
        operation = OP_SLL;
        eval();
        check_equal(result, 16'h0010, "sll_1_by_4");

        // -------------------------------------------------------
        // Test 9: Shift right logical
        // -------------------------------------------------------
        operand_a = 16'h8000;
        operand_b = 16'd4;
        operation = OP_SRL;
        eval();
        check_equal(result, 16'h0800, "srl_8000_by_4");

        // -------------------------------------------------------
        // Test 10: Shift right arithmetic
        // -------------------------------------------------------
        operand_a = 16'h8000;  // Negative in signed
        operand_b = 16'd4;
        operation = OP_SRA;
        eval();
        check_equal(result, 16'hF800, "sra_sign_extend");

        // -------------------------------------------------------
        // Test 11: Pass-through
        // -------------------------------------------------------
        operand_a = 16'h1234;
        operand_b = 16'h5678;
        operation = OP_PASS;
        eval();
        check_equal(result, 16'h1234, "pass_through");

        // -------------------------------------------------------
        // Test 12: Compare
        // -------------------------------------------------------
        operand_a = 16'd100;
        operand_b = 16'd100;
        operation = OP_CMP;
        eval();
        check(zero_flag == 1'b1, "cmp_equal");
        check(carry_flag == 1'b0, "cmp_equal_no_borrow");

        operand_a = 16'd50;
        operand_b = 16'd100;
        operation = OP_CMP;
        eval();
        check(zero_flag == 1'b0, "cmp_less_not_zero");
        check(carry_flag == 1'b1, "cmp_less_borrow");

        // -------------------------------------------------------
        // Test 13: Signed overflow detection
        // -------------------------------------------------------
        operand_a = 16'h7FFF;  // Max positive
        operand_b = 16'h0001;
        operation = OP_ADD;
        eval();
        check(overflow_flag == 1'b1, "signed_overflow_add");

        operand_a = 16'h8000;  // Min negative
        operand_b = 16'h0001;
        operation = OP_SUB;
        eval();
        check(overflow_flag == 1'b1, "signed_overflow_sub");

        // -------------------------------------------------------
        // Test 14: Boundary values
        // -------------------------------------------------------
        operand_a = 16'd0;
        operand_b = 16'd0;
        operation = OP_ADD;
        eval();
        check_equal(result, 16'd0, "add_zero_zero");
        check(zero_flag == 1'b1, "zero_plus_zero_flag");

        operand_a = 16'hFFFF;
        operand_b = 16'hFFFF;
        operation = OP_AND;
        eval();
        check_equal(result, 16'hFFFF, "and_all_ones");

        // -------------------------------------------------------
        // Test 15: Constrained random
        // -------------------------------------------------------
        $display("[%0t] Running 100 random ADD/SUB tests...", $time);
        for (int i = 0; i < 100; i++) begin
            operand_a = $urandom();
            operand_b = $urandom();
            operation = (i % 2 == 0) ? OP_ADD : OP_SUB;
            eval();
            check_equal(result, ref_result(operand_a, operand_b, operation),
                        $sformatf("random_%s_%0d", op_name(operation), i));
        end

        // -------------------------------------------------------
        // Summary
        // -------------------------------------------------------
        #10;
        print_summary("tb_alu");

        $finish;
    end

    // Watchdog
    initial begin
        #1000000;
        $display("ERROR: Watchdog timeout!");
        $display("  ** TEST FAILED **");
        $finish;
    end

endmodule
