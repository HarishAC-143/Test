// =============================================================================
// 32-Bit Arithmetic Logic Unit (ALU)
// Supports arithmetic, logical, shift, and comparison operations.
// =============================================================================

module alu_32bit #(
    parameter DATA_WIDTH = 32
) (
    input  logic [DATA_WIDTH-1:0]   operand_a,
    input  logic [DATA_WIDTH-1:0]   operand_b,
    input  logic [3:0]              alu_op,
    output logic [DATA_WIDTH-1:0]   result,
    output logic                    zero,
    output logic                    carry,
    output logic                    overflow,
    output logic                    negative
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
        ALU_NAND = 4'b1011,
        ALU_MUL  = 4'b1100,
        ALU_PASS = 4'b1111   // Pass operand_a through
    } alu_op_e;

    logic [DATA_WIDTH:0] add_result;
    logic [DATA_WIDTH:0] sub_result;

    always_comb begin
        add_result = {1'b0, operand_a} + {1'b0, operand_b};
        sub_result = {1'b0, operand_a} - {1'b0, operand_b};

        result   = '0;
        carry    = 1'b0;
        overflow = 1'b0;

        case (alu_op)
            ALU_ADD: begin
                result   = add_result[DATA_WIDTH-1:0];
                carry    = add_result[DATA_WIDTH];
                overflow = (operand_a[DATA_WIDTH-1] == operand_b[DATA_WIDTH-1]) &&
                           (result[DATA_WIDTH-1] != operand_a[DATA_WIDTH-1]);
            end

            ALU_SUB: begin
                result   = sub_result[DATA_WIDTH-1:0];
                carry    = sub_result[DATA_WIDTH];
                overflow = (operand_a[DATA_WIDTH-1] != operand_b[DATA_WIDTH-1]) &&
                           (result[DATA_WIDTH-1] != operand_a[DATA_WIDTH-1]);
            end

            ALU_AND:  result = operand_a & operand_b;
            ALU_OR:   result = operand_a | operand_b;
            ALU_XOR:  result = operand_a ^ operand_b;
            ALU_NOR:  result = ~(operand_a | operand_b);
            ALU_NAND: result = ~(operand_a & operand_b);

            ALU_SLL:  result = operand_a << operand_b[4:0];
            ALU_SRL:  result = operand_a >> operand_b[4:0];
            ALU_SRA:  result = $signed(operand_a) >>> operand_b[4:0];

            ALU_SLT:  result = {{(DATA_WIDTH-1){1'b0}}, $signed(operand_a) < $signed(operand_b)};
            ALU_SLTU: result = {{(DATA_WIDTH-1){1'b0}}, operand_a < operand_b};

            ALU_MUL:  result = operand_a[15:0] * operand_b[15:0];

            ALU_PASS: result = operand_a;

            default:  result = '0;
        endcase
    end

    assign zero     = (result == '0);
    assign negative = result[DATA_WIDTH-1];

endmodule
