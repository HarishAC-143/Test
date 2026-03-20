// ============================================================================
// Arithmetic Logic Unit (ALU)
// ============================================================================
// Parameterized ALU supporting arithmetic, logical, and comparison operations.
// Uses `always_comb` and `unique case` for safe, synthesizable combinational
// logic without latch inference.
// ============================================================================

module alu #(
    parameter int WIDTH = 32
)(
    input  logic [WIDTH-1:0] a,
    input  logic [WIDTH-1:0] b,
    input  logic [3:0]       op,
    output logic [WIDTH-1:0] result,
    output logic             zero,
    output logic             carry,
    output logic             overflow
);

    logic [WIDTH:0] add_result;
    logic [WIDTH:0] sub_result;

    always_comb begin
        result   = '0;
        carry    = 1'b0;
        overflow = 1'b0;

        add_result = {1'b0, a} + {1'b0, b};
        sub_result = {1'b0, a} - {1'b0, b};

        unique case (op)
            4'h0: begin  // ADD
                result   = add_result[WIDTH-1:0];
                carry    = add_result[WIDTH];
                overflow = (a[WIDTH-1] == b[WIDTH-1]) &&
                           (result[WIDTH-1] != a[WIDTH-1]);
            end
            4'h1: begin  // SUB
                result   = sub_result[WIDTH-1:0];
                carry    = sub_result[WIDTH];
                overflow = (a[WIDTH-1] != b[WIDTH-1]) &&
                           (result[WIDTH-1] != a[WIDTH-1]);
            end
            4'h2: result = a & b;                           // AND
            4'h3: result = a | b;                           // OR
            4'h4: result = a ^ b;                           // XOR
            4'h5: result = ~a;                              // NOT
            4'h6: result = a << b[$clog2(WIDTH)-1:0];       // SLL
            4'h7: result = a >> b[$clog2(WIDTH)-1:0];       // SRL
            4'h8: result = $signed(a) >>> b[$clog2(WIDTH)-1:0]; // SRA
            4'h9: result = {{(WIDTH-1){1'b0}},              // SLT (signed)
                            $signed(a) < $signed(b)};
            4'hA: result = {{(WIDTH-1){1'b0}}, a < b};     // SLTU (unsigned)
            default: result = '0;
        endcase

        zero = (result == '0);
    end

endmodule
