// Parameterized 4-to-1 Multiplexer
// Selects one of four inputs based on a 2-bit selector.

module mux4to1 #(
    parameter WIDTH = 8
)(
    input  logic [WIDTH-1:0] in0,
    input  logic [WIDTH-1:0] in1,
    input  logic [WIDTH-1:0] in2,
    input  logic [WIDTH-1:0] in3,
    input  logic [1:0]       sel,
    output logic [WIDTH-1:0] out
);

    always_comb begin
        case (sel)
            2'b00:   out = in0;
            2'b01:   out = in1;
            2'b10:   out = in2;
            2'b11:   out = in3;
            default: out = '0;
        endcase
    end

endmodule
