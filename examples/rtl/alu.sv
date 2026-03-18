// Parameterized ALU supporting arithmetic, logical, and shift operations.
// Operation encoding designed for easy decode; DSP-block-friendly multiplication.

module alu #(
    parameter int WIDTH = 16
)(
    input  logic [WIDTH-1:0] operand_a,
    input  logic [WIDTH-1:0] operand_b,
    input  logic [3:0]       operation,
    output logic [WIDTH-1:0] result,
    output logic             zero_flag,
    output logic             carry_flag,
    output logic             overflow_flag
);

    // Operation codes
    localparam logic [3:0] OP_ADD  = 4'b0000;
    localparam logic [3:0] OP_SUB  = 4'b0001;
    localparam logic [3:0] OP_MUL  = 4'b0010;
    localparam logic [3:0] OP_AND  = 4'b0011;
    localparam logic [3:0] OP_OR   = 4'b0100;
    localparam logic [3:0] OP_XOR  = 4'b0101;
    localparam logic [3:0] OP_NOT  = 4'b0110;
    localparam logic [3:0] OP_SLL  = 4'b0111;  // Shift left logical
    localparam logic [3:0] OP_SRL  = 4'b1000;  // Shift right logical
    localparam logic [3:0] OP_SRA  = 4'b1001;  // Shift right arithmetic
    localparam logic [3:0] OP_PASS = 4'b1010;  // Pass-through operand_a
    localparam logic [3:0] OP_CMP  = 4'b1011;  // Compare (subtract, discard result)

    logic [WIDTH:0]     add_result;
    logic [WIDTH:0]     sub_result;
    logic [2*WIDTH-1:0] mul_result;

    // Arithmetic operations (carry-chain friendly)
    assign add_result = {1'b0, operand_a} + {1'b0, operand_b};
    assign sub_result = {1'b0, operand_a} - {1'b0, operand_b};
    assign mul_result = operand_a * operand_b;

    // Result mux
    always_comb begin
        result    = '0;
        carry_flag = 1'b0;

        case (operation)
            OP_ADD: begin
                result     = add_result[WIDTH-1:0];
                carry_flag = add_result[WIDTH];
            end

            OP_SUB: begin
                result     = sub_result[WIDTH-1:0];
                carry_flag = sub_result[WIDTH];  // Borrow
            end

            OP_MUL: begin
                result = mul_result[WIDTH-1:0];
            end

            OP_AND:  result = operand_a & operand_b;
            OP_OR:   result = operand_a | operand_b;
            OP_XOR:  result = operand_a ^ operand_b;
            OP_NOT:  result = ~operand_a;

            OP_SLL:  result = operand_a << operand_b[$clog2(WIDTH)-1:0];
            OP_SRL:  result = operand_a >> operand_b[$clog2(WIDTH)-1:0];
            OP_SRA:  result = $signed(operand_a) >>> operand_b[$clog2(WIDTH)-1:0];

            OP_PASS: result = operand_a;

            OP_CMP: begin
                result     = sub_result[WIDTH-1:0];
                carry_flag = sub_result[WIDTH];
            end

            default: result = '0;
        endcase
    end

    // Flags
    assign zero_flag = (result == '0);

    // Signed overflow: both operands same sign, result different sign
    assign overflow_flag = (operation == OP_ADD) ?
        (operand_a[WIDTH-1] == operand_b[WIDTH-1]) && (result[WIDTH-1] != operand_a[WIDTH-1]) :
        (operation == OP_SUB) ?
        (operand_a[WIDTH-1] != operand_b[WIDTH-1]) && (result[WIDTH-1] != operand_a[WIDTH-1]) :
        1'b0;

endmodule
