// ----------------------------------------------------------------------------
// Parameterized Round-Robin Arbiter with Grant Holding
// Demonstrates: priority rotation, thermometer encoding, configurable
//               fairness, grant-hold for multi-cycle transactions
// ----------------------------------------------------------------------------

module round_robin_arbiter #(
    parameter int NUM_PORTS   = 8,
    parameter bit GRANT_HOLD  = 1   // Hold grant until requestor deasserts
)(
    input  logic                     clk,
    input  logic                     rst_n,
    input  logic [NUM_PORTS-1:0]     request,
    input  logic [NUM_PORTS-1:0]     lock,       // Hold grant for multi-cycle ops
    output logic [NUM_PORTS-1:0]     grant,
    output logic                     grant_valid
);

    logic [NUM_PORTS-1:0] mask;
    logic [NUM_PORTS-1:0] masked_request;
    logic [NUM_PORTS-1:0] next_grant;
    logic [NUM_PORTS-1:0] grant_held;
    logic                 holding;

    // Current grant is locked by the requestor
    assign holding = |(grant & lock);

    // Mask lower-priority requestors
    assign masked_request = request & mask;

    // Find lowest-set-bit (priority encode) for both masked and unmasked
    logic [NUM_PORTS-1:0] masked_lsb;
    logic [NUM_PORTS-1:0] unmasked_lsb;

    assign masked_lsb   = masked_request & (~masked_request + 1'b1);
    assign unmasked_lsb = request & (~request + 1'b1);

    // Select masked if any masked request exists, otherwise wrap around
    assign next_grant = |masked_request ? masked_lsb : unmasked_lsb;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            grant       <= '0;
            grant_valid <= 1'b0;
            mask        <= '1;
        end else begin
            if (holding) begin
                // Maintain current grant while locked
                grant       <= grant;
                grant_valid <= 1'b1;
            end else if (|request) begin
                grant       <= next_grant;
                grant_valid <= 1'b1;

                // Update mask: set bits above granted position
                for (int i = 0; i < NUM_PORTS; i++) begin
                    if (next_grant[i]) begin
                        mask <= ({NUM_PORTS{1'b1}} << (i + 1));
                    end
                end
            end else begin
                grant       <= '0;
                grant_valid <= 1'b0;
            end
        end
    end

endmodule
