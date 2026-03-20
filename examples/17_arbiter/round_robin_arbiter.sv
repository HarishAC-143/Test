// ============================================================================
// Round-Robin Arbiter
// ============================================================================
// Grants access to N requestors in a fair, round-robin order. After a
// requestor is granted, it moves to lowest priority and all others shift
// up. If no masked request is active, falls back to fixed-priority
// (thermometer-mask style).
//
// This is the standard arbiter used in:
//   - Bus crossbars and interconnects
//   - Multi-port memory controllers
//   - Packet schedulers
//   - DMA channel arbitration
// ============================================================================

module round_robin_arbiter #(
    parameter int NUM_REQ = 4
)(
    input  logic                clk,
    input  logic                rst_n,
    input  logic [NUM_REQ-1:0]  req,
    output logic [NUM_REQ-1:0]  grant,
    output logic                valid
);

    logic [NUM_REQ-1:0] mask;
    logic [NUM_REQ-1:0] masked_req;
    logic [NUM_REQ-1:0] grant_masked, grant_unmasked;

    assign masked_req = req & mask;
    assign valid      = |req;

    // Fixed-priority encoder on masked requests
    always_comb begin
        grant_masked = '0;
        for (int i = 0; i < NUM_REQ; i++) begin
            if (masked_req[i]) begin
                grant_masked[i] = 1'b1;
                break;
            end
        end
    end

    // Fixed-priority encoder on unmasked requests (fallback)
    always_comb begin
        grant_unmasked = '0;
        for (int i = 0; i < NUM_REQ; i++) begin
            if (req[i]) begin
                grant_unmasked[i] = 1'b1;
                break;
            end
        end
    end

    // Use masked grant if available, otherwise unmasked
    assign grant = (|masked_req) ? grant_masked : grant_unmasked;

    // Update mask: suppress all bits at and below the granted position
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mask <= '1;
        end else if (valid) begin
            // Create a thermometer mask: 1s above the granted bit, 0s at and below
            for (int i = 0; i < NUM_REQ; i++) begin
                if (grant[i]) begin
                    for (int j = 0; j < NUM_REQ; j++)
                        mask[j] <= (j > i);
                end
            end
        end
    end

endmodule


// ============================================================================
// Fixed-Priority Arbiter
// ============================================================================
// For comparison: a simple fixed-priority arbiter where bit 0 has the
// highest priority. Simpler but unfair — can starve higher-numbered ports.
// ============================================================================

module fixed_priority_arbiter #(
    parameter int NUM_REQ = 4
)(
    input  logic [NUM_REQ-1:0] req,
    output logic [NUM_REQ-1:0] grant,
    output logic               valid
);

    assign valid = |req;

    always_comb begin
        grant = '0;
        for (int i = 0; i < NUM_REQ; i++) begin
            if (req[i]) begin
                grant[i] = 1'b1;
                break;
            end
        end
    end

endmodule
