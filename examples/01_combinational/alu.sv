// Simple Arithmetic Logic Unit (ALU)
// Supports: ADD, SUB, AND, OR, XOR, SLL, SRL, SRA, SLT, SLTU

module alu #(
    parameter WIDTH = 32
)(
    input  logic [WIDTH-1:0] operand_a,
    input  logic [WIDTH-1:0] operand_b,
    input  logic [3:0]       alu_op,
    output logic [WIDTH-1:0] result,
    output logic             zero,
    output logic             carry,
    output logic             overflow
);

    typedef enum logic [3:0] {
        ALU_ADD  = 4'b0000,
        ALU_SUB  = 4'b0001,
        ALU_AND  = 4'b0010,
        ALU_OR   = 4'b0011,
        ALU_XOR  = 4'b0100,
        ALU_SLL  = 4'b0101,
        ALU_SRL  = 4'b0110,
        ALU_SRA  = 4'b0111,
        ALU_SLT  = 4'b1000,
        ALU_SLTU = 4'b1001
    } alu_op_e;

    logic [WIDTH:0] sum;
    logic [WIDTH:0] diff;

    assign sum  = {1'b0, operand_a} + {1'b0, operand_b};
    assign diff = {1'b0, operand_a} - {1'b0, operand_b};

    always_comb begin
        result   = '0;
        carry    = 1'b0;
        overflow = 1'b0;

        case (alu_op)
            ALU_ADD: begin
                result   = sum[WIDTH-1:0];
                carry    = sum[WIDTH];
                overflow = (operand_a[WIDTH-1] == operand_b[WIDTH-1]) &&
                           (result[WIDTH-1] != operand_a[WIDTH-1]);
            end

            ALU_SUB: begin
                result   = diff[WIDTH-1:0];
                carry    = diff[WIDTH];
                overflow = (operand_a[WIDTH-1] != operand_b[WIDTH-1]) &&
                           (result[WIDTH-1] != operand_a[WIDTH-1]);
            end

            ALU_AND:  result = operand_a & operand_b;
            ALU_OR:   result = operand_a | operand_b;
            ALU_XOR:  result = operand_a ^ operand_b;

            ALU_SLL:  result = operand_a << operand_b[$clog2(WIDTH)-1:0];
            ALU_SRL:  result = operand_a >> operand_b[$clog2(WIDTH)-1:0];
            ALU_SRA:  result = $signed(operand_a) >>> operand_b[$clog2(WIDTH)-1:0];

            ALU_SLT:  result = {{(WIDTH-1){1'b0}}, $signed(operand_a) < $signed(operand_b)};
            ALU_SLTU: result = {{(WIDTH-1){1'b0}}, operand_a < operand_b};

            default:  result = '0;
        endcase
    end

    assign zero = (result == '0);

endmodule
