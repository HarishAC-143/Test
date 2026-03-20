// Parameterized 4:1 multiplexer.

module mux4to1 #(
    parameter int WIDTH = 8
)(
    input  logic [1:0]       sel,
    input  logic [WIDTH-1:0] in0,
    input  logic [WIDTH-1:0] in1,
    input  logic [WIDTH-1:0] in2,
    input  logic [WIDTH-1:0] in3,
    output logic [WIDTH-1:0] out
);

    always_comb begin
        unique case (sel)
            2'b00:   out = in0;
            2'b01:   out = in1;
            2'b10:   out = in2;
            2'b11:   out = in3;
            default: out = '0;
        endcase
    end

endmodule
