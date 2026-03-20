// Simple arithmetic-logic unit demonstrating `unique case`.
// Supports 8 operations on parameterized-width operands.

module alu #(
    parameter int WIDTH = 8
)(
    input  logic [WIDTH-1:0] a,
    input  logic [WIDTH-1:0] b,
    input  logic [2:0]       op,
    output logic [WIDTH-1:0] result,
    output logic             zero,
    output logic             carry,
    output logic             overflow
);

    localparam logic [2:0] OP_ADD  = 3'b000;
    localparam logic [2:0] OP_SUB  = 3'b001;
    localparam logic [2:0] OP_AND  = 3'b010;
    localparam logic [2:0] OP_OR   = 3'b011;
    localparam logic [2:0] OP_XOR  = 3'b100;
    localparam logic [2:0] OP_SLL  = 3'b101;  // shift left logical
    localparam logic [2:0] OP_SRL  = 3'b110;  // shift right logical
    localparam logic [2:0] OP_SRA  = 3'b111;  // shift right arithmetic

    logic [WIDTH:0] full_result;

    always_comb begin
        full_result = '0;
        overflow    = 1'b0;

        unique case (op)
            OP_ADD: begin
                full_result = {1'b0, a} + {1'b0, b};
                overflow = (a[WIDTH-1] == b[WIDTH-1]) &&
                           (full_result[WIDTH-1] != a[WIDTH-1]);
            end

            OP_SUB: begin
                full_result = {1'b0, a} - {1'b0, b};
                overflow = (a[WIDTH-1] != b[WIDTH-1]) &&
                           (full_result[WIDTH-1] != a[WIDTH-1]);
            end

            OP_AND: full_result = {1'b0, a & b};
            OP_OR:  full_result = {1'b0, a | b};
            OP_XOR: full_result = {1'b0, a ^ b};
            OP_SLL: full_result = {1'b0, a << b[$clog2(WIDTH)-1:0]};
            OP_SRL: full_result = {1'b0, a >> b[$clog2(WIDTH)-1:0]};

            OP_SRA: begin
                full_result = {1'b0, WIDTH'($signed(a) >>> b[$clog2(WIDTH)-1:0])};
            end

            default: full_result = '0;
        endcase
    end

    assign result = full_result[WIDTH-1:0];
    assign carry  = full_result[WIDTH];
    assign zero   = (result == '0);

endmodule
