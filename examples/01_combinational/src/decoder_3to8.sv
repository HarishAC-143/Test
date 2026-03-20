// 3-to-8 Decoder with Enable
// Asserts exactly one of 8 output lines based on a 3-bit input.
// When enable is low, all outputs are deasserted.

module decoder_3to8 (
    input  logic [2:0] in,
    input  logic       enable,
    output logic [7:0] out
);

    always_comb begin
        if (enable)
            out = 8'b0000_0001 << in;
        else
            out = 8'b0000_0000;
    end

endmodule
