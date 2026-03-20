// 8-to-3 Priority Encoder
// Returns the index of the highest-priority (MSB) active request.
// The 'valid' output indicates at least one request is active.

module priority_encoder #(
    parameter IN_WIDTH  = 8,
    parameter OUT_WIDTH = $clog2(IN_WIDTH)
)(
    input  logic [IN_WIDTH-1:0]  req,
    output logic [OUT_WIDTH-1:0] grant_idx,
    output logic                 valid
);

    always_comb begin
        valid     = 1'b0;
        grant_idx = '0;

        for (int i = 0; i < IN_WIDTH; i++) begin
            if (req[i]) begin
                grant_idx = OUT_WIDTH'(i);
                valid     = 1'b1;
            end
        end
    end

endmodule
