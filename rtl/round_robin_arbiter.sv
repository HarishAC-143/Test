// =============================================================================
// Round-Robin Arbiter with Priority Override
// Demonstrates: Arbitration logic, generate blocks, priority encoding
// =============================================================================

module round_robin_arbiter #(
    parameter int NUM_REQUESTORS = 4
) (
    input  logic                      clk,
    input  logic                      rst_n,

    input  logic [NUM_REQUESTORS-1:0] req,
    input  logic [NUM_REQUESTORS-1:0] priority_req,  // High-priority override
    output logic [NUM_REQUESTORS-1:0] grant,
    output logic                      grant_valid
);

    logic [NUM_REQUESTORS-1:0] mask;
    logic [NUM_REQUESTORS-1:0] masked_req;
    logic [NUM_REQUESTORS-1:0] unmasked_grant;
    logic [NUM_REQUESTORS-1:0] masked_grant;
    logic [NUM_REQUESTORS-1:0] priority_grant;

    assign masked_req = req & mask;

    // Priority encoder for masked requests (round-robin fairness)
    always_comb begin
        masked_grant = '0;
        for (int i = 0; i < NUM_REQUESTORS; i++) begin
            if (masked_req[i]) begin
                masked_grant = '0;
                masked_grant[i] = 1'b1;
                break;
            end
        end
    end

    // Priority encoder for unmasked requests (wrap-around)
    always_comb begin
        unmasked_grant = '0;
        for (int i = 0; i < NUM_REQUESTORS; i++) begin
            if (req[i]) begin
                unmasked_grant = '0;
                unmasked_grant[i] = 1'b1;
                break;
            end
        end
    end

    // Priority override encoder
    always_comb begin
        priority_grant = '0;
        for (int i = 0; i < NUM_REQUESTORS; i++) begin
            if (priority_req[i]) begin
                priority_grant = '0;
                priority_grant[i] = 1'b1;
                break;
            end
        end
    end

    // Grant selection: priority > masked round-robin > unmasked round-robin
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            grant       <= '0;
            grant_valid <= 1'b0;
            mask        <= '1;  // All bits set initially
        end else begin
            if (|priority_req) begin
                grant       <= priority_grant;
                grant_valid <= 1'b1;
                // Update mask: clear bits at and below granted position
                for (int i = 0; i < NUM_REQUESTORS; i++) begin
                    if (priority_grant[i])
                        mask <= ({NUM_REQUESTORS{1'b1}} << (i + 1));
                end
            end else if (|masked_req) begin
                grant       <= masked_grant;
                grant_valid <= 1'b1;
                for (int i = 0; i < NUM_REQUESTORS; i++) begin
                    if (masked_grant[i])
                        mask <= ({NUM_REQUESTORS{1'b1}} << (i + 1));
                end
            end else if (|req) begin
                grant       <= unmasked_grant;
                grant_valid <= 1'b1;
                for (int i = 0; i < NUM_REQUESTORS; i++) begin
                    if (unmasked_grant[i])
                        mask <= ({NUM_REQUESTORS{1'b1}} << (i + 1));
                end
            end else begin
                grant       <= '0;
                grant_valid <= 1'b0;
            end
        end
    end

    // Assertion: only one grant active at a time
    assert property (@(posedge clk) disable iff (!rst_n)
        $onehot0(grant)
    ) else $error("Multiple grants asserted simultaneously!");

endmodule
