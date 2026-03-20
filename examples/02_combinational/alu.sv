// Arithmetic Logic Unit (ALU)
// Demonstrates combinational arithmetic and logic operations

module alu #(
    parameter int WIDTH = 32
) (
    input  logic [WIDTH-1:0]  operand_a,
    input  logic [WIDTH-1:0]  operand_b,
    input  logic [3:0]        operation,
    output logic [WIDTH-1:0]  result,
    output logic              zero_flag,
    output logic              carry_flag,
    output logic              overflow_flag
);

    typedef enum logic [3:0] {
        ALU_ADD  = 4'b0000,
        ALU_SUB  = 4'b0001,
        ALU_AND  = 4'b0010,
        ALU_OR   = 4'b0011,
        ALU_XOR  = 4'b0100,
        ALU_SLL  = 4'b0101,  // Shift Left Logical
        ALU_SRL  = 4'b0110,  // Shift Right Logical
        ALU_SRA  = 4'b0111,  // Shift Right Arithmetic
        ALU_SLT  = 4'b1000,  // Set Less Than (signed)
        ALU_SLTU = 4'b1001,  // Set Less Than (unsigned)
        ALU_NOR  = 4'b1010,
        ALU_NAND = 4'b1011
    } alu_op_e;

    logic [WIDTH:0] add_result;

    always_comb begin
        result        = '0;
        carry_flag    = 1'b0;
        overflow_flag = 1'b0;

        unique case (alu_op_e'(operation))
            ALU_ADD: begin
                add_result    = {1'b0, operand_a} + {1'b0, operand_b};
                result        = add_result[WIDTH-1:0];
                carry_flag    = add_result[WIDTH];
                overflow_flag = (operand_a[WIDTH-1] == operand_b[WIDTH-1]) &&
                                (result[WIDTH-1] != operand_a[WIDTH-1]);
            end

            ALU_SUB: begin
                add_result    = {1'b0, operand_a} - {1'b0, operand_b};
                result        = add_result[WIDTH-1:0];
                carry_flag    = add_result[WIDTH];
                overflow_flag = (operand_a[WIDTH-1] != operand_b[WIDTH-1]) &&
                                (result[WIDTH-1] != operand_a[WIDTH-1]);
            end

            ALU_AND:  result = operand_a & operand_b;
            ALU_OR:   result = operand_a | operand_b;
            ALU_XOR:  result = operand_a ^ operand_b;
            ALU_NOR:  result = ~(operand_a | operand_b);
            ALU_NAND: result = ~(operand_a & operand_b);

            ALU_SLL:  result = operand_a << operand_b[$clog2(WIDTH)-1:0];
            ALU_SRL:  result = operand_a >> operand_b[$clog2(WIDTH)-1:0];
            ALU_SRA:  result = $signed(operand_a) >>> operand_b[$clog2(WIDTH)-1:0];

            ALU_SLT:  result = {{(WIDTH-1){1'b0}}, $signed(operand_a) < $signed(operand_b)};
            ALU_SLTU: result = {{(WIDTH-1){1'b0}}, operand_a < operand_b};

            default:  result = '0;
        endcase
    end

    assign zero_flag = (result == '0);

endmodule
