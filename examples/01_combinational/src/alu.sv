// Simple Arithmetic Logic Unit (ALU)
// Supports 8 operations selected by a 3-bit opcode.
// Demonstrates enum types and unique case for one-hot checking.

module alu #(
    parameter WIDTH = 16
)(
    input  logic [WIDTH-1:0]   a,
    input  logic [WIDTH-1:0]   b,
    input  logic [2:0]         op,
    output logic [WIDTH-1:0]   result,
    output logic               zero,
    output logic               carry,
    output logic               overflow
);

    typedef enum logic [2:0] {
        OP_ADD  = 3'b000,
        OP_SUB  = 3'b001,
        OP_AND  = 3'b010,
        OP_OR   = 3'b011,
        OP_XOR  = 3'b100,
        OP_SLL  = 3'b101,  // shift left logical
        OP_SRL  = 3'b110,  // shift right logical
        OP_SRA  = 3'b111   // shift right arithmetic
    } alu_op_t;

    logic [WIDTH:0] add_result;
    logic [WIDTH:0] sub_result;

    assign add_result = {1'b0, a} + {1'b0, b};
    assign sub_result = {1'b0, a} - {1'b0, b};

    always_comb begin
        result   = '0;
        carry    = 1'b0;
        overflow = 1'b0;

        unique case (op)
            OP_ADD: begin
                result   = add_result[WIDTH-1:0];
                carry    = add_result[WIDTH];
                overflow = (a[WIDTH-1] == b[WIDTH-1]) &&
                           (result[WIDTH-1] != a[WIDTH-1]);
            end

            OP_SUB: begin
                result   = sub_result[WIDTH-1:0];
                carry    = sub_result[WIDTH];
                overflow = (a[WIDTH-1] != b[WIDTH-1]) &&
                           (result[WIDTH-1] != a[WIDTH-1]);
            end

            OP_AND: result = a & b;
            OP_OR:  result = a | b;
            OP_XOR: result = a ^ b;

            OP_SLL: result = a << b[$clog2(WIDTH)-1:0];
            OP_SRL: result = a >> b[$clog2(WIDTH)-1:0];
            OP_SRA: result = $signed(a) >>> b[$clog2(WIDTH)-1:0];

            default: result = '0;
        endcase
    end

    assign zero = (result == '0);

endmodule
