// ============================================================================
// Priority Encoder
// ============================================================================
// Parameterized priority encoder: given N request bits, outputs the binary
// index of the highest-priority active request (bit 0 = highest priority).
// ============================================================================

module priority_encoder #(
    parameter int NUM_REQ = 8
)(
    input  logic [NUM_REQ-1:0]        req,
    output logic [$clog2(NUM_REQ)-1:0] idx,
    output logic                       valid
);

    always_comb begin
        valid = 1'b0;
        idx   = '0;
        for (int i = 0; i < NUM_REQ; i++) begin
            if (req[i]) begin
                idx   = i[$clog2(NUM_REQ)-1:0];
                valid = 1'b1;
                break;
            end
        end
    end

endmodule
