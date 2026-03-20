// Decoder and Encoder implementations

// 3-to-8 Decoder
module decoder_3to8 (
    input  logic [2:0] in,
    input  logic       enable,
    output logic [7:0] out
);
    always_comb begin
        out = '0;
        if (enable) begin
            out[in] = 1'b1;
        end
    end
endmodule


// 8-to-3 Priority Encoder
module priority_encoder_8to3 (
    input  logic [7:0] in,
    output logic [2:0] out,
    output logic       valid
);
    always_comb begin
        valid = 1'b1;
        casez (in)
            8'b1???_????: out = 3'd7;
            8'b01??_????: out = 3'd6;
            8'b001?_????: out = 3'd5;
            8'b0001_????: out = 3'd4;
            8'b0000_1???: out = 3'd3;
            8'b0000_01??: out = 3'd2;
            8'b0000_001?: out = 3'd1;
            8'b0000_0001: out = 3'd0;
            default: begin
                out   = '0;
                valid = 1'b0;
            end
        endcase
    end
endmodule


// One-hot to binary encoder
module onehot_to_bin #(
    parameter int N = 8
) (
    input  logic [N-1:0]         onehot,
    output logic [$clog2(N)-1:0] bin,
    output logic                 valid
);
    always_comb begin
        bin   = '0;
        valid = 1'b0;
        for (int i = 0; i < N; i++) begin
            if (onehot[i]) begin
                bin   = i[$clog2(N)-1:0];
                valid = 1'b1;
            end
        end
    end
endmodule
