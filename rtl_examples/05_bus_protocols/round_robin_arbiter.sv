// =============================================================================
// Parameterized Round-Robin Arbiter
// Fair arbitration across N requestors with rotating priority.
// Grant is one-hot encoded.
// =============================================================================

module round_robin_arbiter #(
    parameter NUM_REQ = 4
) (
    input  logic                  clk,
    input  logic                  rst_n,
    input  logic [NUM_REQ-1:0]    request,
    output logic [NUM_REQ-1:0]    grant,
    output logic                  valid
);

    logic [NUM_REQ-1:0] mask;
    logic [NUM_REQ-1:0] masked_request;
    logic [NUM_REQ-1:0] unmasked_grant;
    logic [NUM_REQ-1:0] masked_grant;
    logic               use_masked;

    assign masked_request = request & mask;

    // Priority encoders for both masked and unmasked requests
    // Masked: applies round-robin fairness
    // Unmasked: fallback when no masked requests are pending
    always_comb begin
        masked_grant   = '0;
        unmasked_grant = '0;

        // Masked priority encoder
        for (int i = NUM_REQ - 1; i >= 0; i--) begin
            if (masked_request[i])
                masked_grant = NUM_REQ'(1) << i;
        end

        // Unmasked priority encoder
        for (int i = NUM_REQ - 1; i >= 0; i--) begin
            if (request[i])
                unmasked_grant = NUM_REQ'(1) << i;
        end
    end

    assign use_masked = |masked_request;
    assign grant      = use_masked ? masked_grant : unmasked_grant;
    assign valid      = |request;

    // Update mask: after granting, mask out the granted and all lower-priority requests
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mask <= '1;
        end else if (valid) begin
            if (use_masked)
                mask <= {NUM_REQ{1'b1}} << ($clog2(NUM_REQ)'(find_index(masked_grant)) + 1);
            else
                mask <= {NUM_REQ{1'b1}} << ($clog2(NUM_REQ)'(find_index(unmasked_grant)) + 1);
        end
    end

    function automatic int find_index(input logic [NUM_REQ-1:0] onehot);
        find_index = 0;
        for (int i = 0; i < NUM_REQ; i++) begin
            if (onehot[i])
                find_index = i;
        end
    endfunction

endmodule
