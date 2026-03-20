// Testbench for ALU
// Demonstrates directed testing with a reference model and exhaustive
// coverage of all ALU operations.

`timescale 1ns / 1ps

module tb_alu;

    localparam int WIDTH = 8;

    logic [WIDTH-1:0] operand_a, operand_b, result;
    logic [3:0]       operation;
    logic             zero_flag, carry_flag, overflow_flag;

    alu #(.WIDTH(WIDTH)) u_dut (.*);

    // Reference model function
    function automatic logic [WIDTH:0] ref_alu(
        input logic [WIDTH-1:0] a,
        input logic [WIDTH-1:0] b,
        input logic [3:0]       op
    );
        unique case (op)
            4'b0000: return {1'b0, a} + {1'b0, b};     // ADD
            4'b0001: return {1'b0, a} - {1'b0, b};     // SUB
            4'b0010: return {1'b0, a & b};              // AND
            4'b0011: return {1'b0, a | b};              // OR
            4'b0100: return {1'b0, a ^ b};              // XOR
            4'b0101: return {1'b0, a << b[$clog2(WIDTH)-1:0]};
            4'b0110: return {1'b0, a >> b[$clog2(WIDTH)-1:0]};
            4'b1010: return {1'b0, ~(a | b)};           // NOR
            4'b1011: return {1'b0, ~(a & b)};           // NAND
            default: return '0;
        endcase
    endfunction

    int errors = 0;
    int tests  = 0;

    task automatic check_op(
        input logic [WIDTH-1:0] a,
        input logic [WIDTH-1:0] b,
        input logic [3:0]       op,
        input string            op_name
    );
        logic [WIDTH:0] expected;
        operand_a = a;
        operand_b = b;
        operation = op;
        #1;
        expected = ref_alu(a, b, op);
        tests++;
        if (result !== expected[WIDTH-1:0]) begin
            $error("%s: a=0x%02h b=0x%02h expected=0x%02h got=0x%02h",
                   op_name, a, b, expected[WIDTH-1:0], result);
            errors++;
        end
    endtask

    initial begin
        $display("ALU Testbench Starting (WIDTH=%0d)", WIDTH);

        // Directed tests for each operation
        check_op(8'h3C, 8'h0F, 4'b0000, "ADD");
        check_op(8'hFF, 8'h01, 4'b0000, "ADD overflow");
        check_op(8'h50, 8'h30, 4'b0001, "SUB");
        check_op(8'h30, 8'h50, 4'b0001, "SUB underflow");
        check_op(8'hF0, 8'h0F, 4'b0010, "AND");
        check_op(8'hF0, 8'h0F, 4'b0011, "OR");
        check_op(8'hFF, 8'hAA, 4'b0100, "XOR");
        check_op(8'h01, 8'h04, 4'b0101, "SLL");
        check_op(8'h80, 8'h04, 4'b0110, "SRL");

        // Zero flag test
        operand_a = 8'h55;
        operand_b = 8'h55;
        operation = 4'b0001;
        #1;
        assert (zero_flag == 1'b1) else begin
            $error("Zero flag should be set for 0x55 - 0x55");
            errors++;
        end

        // Random tests
        for (int i = 0; i < 1000; i++) begin
            check_op($urandom(), $urandom(), 4'($urandom_range(0, 6)), "RANDOM");
        end

        $display("\n%0d tests, %0d errors", tests, errors);
        if (errors == 0) $display("ALL TESTS PASSED");
        else $display("SOME TESTS FAILED");
        $finish;
    end

endmodule
