// =============================================================================
// Parameterized Priority Encoder
// Returns the index of the highest-priority (MSB) active request.
// =============================================================================

module priority_encoder #(
    parameter NUM_INPUTS  = 8,
    parameter INDEX_WIDTH = $clog2(NUM_INPUTS)
) (
    input  logic [NUM_INPUTS-1:0]   request,
    output logic [INDEX_WIDTH-1:0]  grant_index,
    output logic                    valid
);

    always_comb begin
        grant_index = '0;
        valid       = 1'b0;

        for (int i = 0; i < NUM_INPUTS; i++) begin
            if (request[i]) begin
                grant_index = INDEX_WIDTH'(i);
                valid       = 1'b1;
            end
        end
    end

endmodule

// =============================================================================
// Programmable Priority Encoder with Mask
// Supports masking of inputs and round-robin base rotation.
// =============================================================================

module priority_encoder_masked #(
    parameter NUM_INPUTS  = 8,
    parameter INDEX_WIDTH = $clog2(NUM_INPUTS)
) (
    input  logic [NUM_INPUTS-1:0]   request,
    input  logic [NUM_INPUTS-1:0]   mask,
    input  logic [INDEX_WIDTH-1:0]  base_priority,
    output logic [INDEX_WIDTH-1:0]  grant_index,
    output logic                    valid
);

    logic [NUM_INPUTS-1:0] masked_request;
    logic [2*NUM_INPUTS-1:0] doubled_req;
    logic [2*NUM_INPUTS-1:0] doubled_grant;

    assign masked_request = request & mask;

    // Double the request vector and rotate by base_priority
    // to implement round-robin scanning from an arbitrary start point
    assign doubled_req = {masked_request, masked_request} >> base_priority;

    always_comb begin
        grant_index = '0;
        valid       = 1'b0;
        doubled_grant = '0;

        for (int i = 0; i < NUM_INPUTS; i++) begin
            if (doubled_req[i] && !valid) begin
                grant_index = INDEX_WIDTH'((unsigned'(i) + unsigned'(base_priority)) % NUM_INPUTS);
                valid       = 1'b1;
            end
        end
    end

endmodule
