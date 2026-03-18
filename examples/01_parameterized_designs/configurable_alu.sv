// ----------------------------------------------------------------------------
// Parameterized ALU with Configurable Data Width and Operation Set
// Demonstrates: parameters, localparam, typedef enum, packed structs, generate
// ----------------------------------------------------------------------------

module configurable_alu #(
    parameter int DATA_WIDTH   = 32,
    parameter bit ENABLE_MUL   = 1,
    parameter bit ENABLE_SHIFT = 1
)(
    input  logic                    clk,
    input  logic                    rst_n,
    input  logic [DATA_WIDTH-1:0]   operand_a,
    input  logic [DATA_WIDTH-1:0]   operand_b,
    input  alu_op_t                 operation,
    input  logic                    valid_in,
    output logic [2*DATA_WIDTH-1:0] result,
    output logic                    valid_out,
    output alu_flags_t              flags
);

    localparam int SHIFT_BITS = $clog2(DATA_WIDTH);

    typedef enum logic [3:0] {
        ALU_ADD  = 4'b0000,
        ALU_SUB  = 4'b0001,
        ALU_AND  = 4'b0010,
        ALU_OR   = 4'b0011,
        ALU_XOR  = 4'b0100,
        ALU_SLL  = 4'b0101,
        ALU_SRL  = 4'b0110,
        ALU_SRA  = 4'b0111,
        ALU_MUL  = 4'b1000,
        ALU_MULU = 4'b1001,
        ALU_NOP  = 4'b1111
    } alu_op_t;

    typedef struct packed {
        logic zero;
        logic negative;
        logic carry;
        logic overflow;
    } alu_flags_t;

    logic [2*DATA_WIDTH-1:0] result_comb;
    alu_flags_t              flags_comb;

    always_comb begin
        result_comb = '0;
        flags_comb  = '0;

        case (operation)
            ALU_ADD: begin
                {flags_comb.carry, result_comb[DATA_WIDTH-1:0]} =
                    {1'b0, operand_a} + {1'b0, operand_b};
                flags_comb.overflow =
                    (operand_a[DATA_WIDTH-1] == operand_b[DATA_WIDTH-1]) &&
                    (result_comb[DATA_WIDTH-1] != operand_a[DATA_WIDTH-1]);
            end

            ALU_SUB: begin
                {flags_comb.carry, result_comb[DATA_WIDTH-1:0]} =
                    {1'b0, operand_a} - {1'b0, operand_b};
                flags_comb.overflow =
                    (operand_a[DATA_WIDTH-1] != operand_b[DATA_WIDTH-1]) &&
                    (result_comb[DATA_WIDTH-1] != operand_a[DATA_WIDTH-1]);
            end

            ALU_AND: result_comb[DATA_WIDTH-1:0] = operand_a & operand_b;
            ALU_OR:  result_comb[DATA_WIDTH-1:0] = operand_a | operand_b;
            ALU_XOR: result_comb[DATA_WIDTH-1:0] = operand_a ^ operand_b;

            ALU_SLL: begin
                if (ENABLE_SHIFT)
                    result_comb[DATA_WIDTH-1:0] = operand_a << operand_b[SHIFT_BITS-1:0];
            end

            ALU_SRL: begin
                if (ENABLE_SHIFT)
                    result_comb[DATA_WIDTH-1:0] = operand_a >> operand_b[SHIFT_BITS-1:0];
            end

            ALU_SRA: begin
                if (ENABLE_SHIFT)
                    result_comb[DATA_WIDTH-1:0] =
                        $signed(operand_a) >>> operand_b[SHIFT_BITS-1:0];
            end

            ALU_MUL: begin
                if (ENABLE_MUL)
                    result_comb = $signed(operand_a) * $signed(operand_b);
            end

            ALU_MULU: begin
                if (ENABLE_MUL)
                    result_comb = operand_a * operand_b;
            end

            default: result_comb = '0;
        endcase

        flags_comb.zero     = (result_comb[DATA_WIDTH-1:0] == '0);
        flags_comb.negative = result_comb[DATA_WIDTH-1];
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result    <= '0;
            valid_out <= 1'b0;
            flags     <= '0;
        end else begin
            result    <= result_comb;
            valid_out <= valid_in;
            flags     <= flags_comb;
        end
    end

endmodule
