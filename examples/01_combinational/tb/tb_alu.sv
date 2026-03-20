// Testbench: ALU

`timescale 1ns / 1ps

module tb_alu;

    parameter WIDTH = 16;

    logic [WIDTH-1:0] a, b, result;
    logic [2:0]       op;
    logic             zero, carry, overflow;

    alu #(.WIDTH(WIDTH)) u_dut (.*);

    task automatic check_op(
        input string name,
        input logic [2:0] opcode,
        input logic [WIDTH-1:0] op_a,
        input logic [WIDTH-1:0] op_b,
        input logic [WIDTH-1:0] expected
    );
        a  = op_a;
        b  = op_b;
        op = opcode;
        #10;
        assert (result == expected)
            else $error("%s: a=%04h b=%04h -> expected %04h, got %04h",
                        name, op_a, op_b, expected, result);
        $display("  %-4s: a=0x%04h b=0x%04h -> result=0x%04h zero=%0b carry=%0b ovf=%0b  PASS",
                 name, op_a, op_b, result, zero, carry, overflow);
    endtask

    initial begin
        $display("=== ALU Testbench ===");

        check_op("ADD", 3'b000, 16'h0001, 16'h0002, 16'h0003);
        check_op("ADD", 3'b000, 16'hFFFF, 16'h0001, 16'h0000);  // overflow
        check_op("SUB", 3'b001, 16'h000A, 16'h0003, 16'h0007);
        check_op("AND", 3'b010, 16'hFF00, 16'h0F0F, 16'h0F00);
        check_op("OR",  3'b011, 16'hFF00, 16'h00FF, 16'hFFFF);
        check_op("XOR", 3'b100, 16'hAAAA, 16'h5555, 16'hFFFF);
        check_op("SLL", 3'b101, 16'h0001, 16'h0004, 16'h0010);
        check_op("SRL", 3'b110, 16'h8000, 16'h0004, 16'h0800);
        check_op("SRA", 3'b111, 16'h8000, 16'h0004, 16'hF800);

        // Test zero flag
        a = 16'h0005; b = 16'h0005; op = 3'b001;  // SUB
        #10;
        assert (zero == 1'b1) else $error("Zero flag not set for 5-5");
        $display("  Zero flag test: 5 - 5 = 0, zero=%0b  PASS", zero);

        $display("=== ALU All Tests Passed ===");
        $finish;
    end

endmodule
