// Parameterized Decoder: N-bit input produces 2^N-bit one-hot output

module decoder #(
    parameter N = 3
)(
    input  logic [N-1:0]     encoded,
    input  logic             enable,
    output logic [(1<<N)-1:0] decoded
);

    always_comb begin
        decoded = '0;
        if (enable)
            decoded[encoded] = 1'b1;
    end

endmodule


// Priority Encoder: returns the index of the highest-priority active input
module priority_encoder #(
    parameter N = 8
)(
    input  logic [N-1:0]              req,
    output logic [$clog2(N)-1:0]      idx,
    output logic                      valid
);

    always_comb begin
        idx   = '0;
        valid = 1'b0;
        for (int i = N-1; i >= 0; i--) begin
            if (req[i]) begin
                idx   = i[$clog2(N)-1:0];
                valid = 1'b1;
                break;
            end
        end
    end

endmodule
