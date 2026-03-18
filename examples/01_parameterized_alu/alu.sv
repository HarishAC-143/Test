// Parameterized ALU
// Supports configurable data width with arithmetic, logical,
// shift, and comparison operations.

module alu
    import alu_pkg::*;
#(
    parameter int WIDTH = 32
) (
    input  logic [WIDTH-1:0] operand_a,
    input  logic [WIDTH-1:0] operand_b,
    input  alu_op_t          alu_op,
    output logic [WIDTH-1:0] result,
    output alu_flags_t       flags
);

    logic [WIDTH:0] adder_result;
    logic            signed_overflow;

    always_comb begin
        adder_result    = '0;
        result          = '0;
        signed_overflow = 1'b0;

        unique case (alu_op)
            ALU_ADD: begin
                adder_result = {1'b0, operand_a} + {1'b0, operand_b};
                result       = adder_result[WIDTH-1:0];
                signed_overflow = (operand_a[WIDTH-1] == operand_b[WIDTH-1]) &&
                                  (result[WIDTH-1]    != operand_a[WIDTH-1]);
            end

            ALU_SUB: begin
                adder_result = {1'b0, operand_a} - {1'b0, operand_b};
                result       = adder_result[WIDTH-1:0];
                signed_overflow = (operand_a[WIDTH-1] != operand_b[WIDTH-1]) &&
                                  (result[WIDTH-1]    != operand_a[WIDTH-1]);
            end

            ALU_AND:  result = operand_a & operand_b;
            ALU_OR:   result = operand_a | operand_b;
            ALU_XOR:  result = operand_a ^ operand_b;
            ALU_NOR:  result = ~(operand_a | operand_b);
            ALU_XNOR: result = ~(operand_a ^ operand_b);

            ALU_SLL: result = operand_a << operand_b[$clog2(WIDTH)-1:0];
            ALU_SRL: result = operand_a >> operand_b[$clog2(WIDTH)-1:0];
            ALU_SRA: result = $signed(operand_a) >>> operand_b[$clog2(WIDTH)-1:0];

            ALU_SLT:  result = {{(WIDTH-1){1'b0}}, $signed(operand_a) < $signed(operand_b)};
            ALU_SLTU: result = {{(WIDTH-1){1'b0}}, operand_a < operand_b};

            ALU_PASS: result = operand_a;

            default: result = '0;
        endcase
    end

    always_comb begin
        flags.zero     = (result == '0);
        flags.negative = result[WIDTH-1];
        flags.overflow = signed_overflow;
        flags.carry    = (alu_op == ALU_ADD || alu_op == ALU_SUB) ? adder_result[WIDTH] : 1'b0;
    end

endmodule
