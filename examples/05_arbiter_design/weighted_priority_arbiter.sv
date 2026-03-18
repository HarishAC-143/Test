// ----------------------------------------------------------------------------
// Weighted Priority Arbiter with Programmable Bandwidth Allocation
// Demonstrates: credit-based arbitration, programmable weights,
//               starvation prevention, dynamic priority adjustment
// ----------------------------------------------------------------------------

module weighted_priority_arbiter #(
    parameter int NUM_PORTS    = 4,
    parameter int WEIGHT_WIDTH = 8,
    parameter int DATA_WIDTH   = 32
)(
    input  logic                            clk,
    input  logic                            rst_n,

    // Weight configuration (runtime programmable)
    input  logic [WEIGHT_WIDTH-1:0]         weights [NUM_PORTS],

    // Request/grant interface
    input  logic [NUM_PORTS-1:0]            request,
    input  logic [DATA_WIDTH-1:0]           req_data [NUM_PORTS],
    output logic [NUM_PORTS-1:0]            grant,
    output logic [DATA_WIDTH-1:0]           grant_data,
    output logic                            grant_valid,
    output logic [$clog2(NUM_PORTS)-1:0]    grant_id
);

    logic [WEIGHT_WIDTH-1:0] credits [NUM_PORTS];
    logic [NUM_PORTS-1:0]    eligible;
    logic [NUM_PORTS-1:0]    selected;
    logic                    any_eligible;
    logic                    reload_credits;

    // A port is eligible if it has a pending request AND remaining credits
    always_comb begin
        for (int i = 0; i < NUM_PORTS; i++)
            eligible[i] = request[i] && (credits[i] > '0);
    end

    assign any_eligible  = |eligible;
    assign reload_credits = |request && !any_eligible;

    // Fixed-priority select among eligible requestors
    // Higher index = higher base priority (configurable via weights)
    always_comb begin
        selected = '0;
        for (int i = NUM_PORTS - 1; i >= 0; i--) begin
            if (eligible[i] && selected == '0)
                selected[i] = 1'b1;
        end
    end

    // Credit management
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < NUM_PORTS; i++)
                credits[i] <= weights[i];
            grant       <= '0;
            grant_valid <= 1'b0;
            grant_data  <= '0;
            grant_id    <= '0;
        end else begin
            if (reload_credits) begin
                // All eligible credits exhausted: reload
                for (int i = 0; i < NUM_PORTS; i++)
                    credits[i] <= weights[i];
                grant       <= '0;
                grant_valid <= 1'b0;
            end else if (any_eligible) begin
                grant       <= selected;
                grant_valid <= 1'b1;

                for (int i = 0; i < NUM_PORTS; i++) begin
                    if (selected[i]) begin
                        credits[i] <= credits[i] - 1'b1;
                        grant_data <= req_data[i];
                        grant_id   <= i[$clog2(NUM_PORTS)-1:0];
                    end
                end
            end else begin
                grant       <= '0;
                grant_valid <= 1'b0;
            end
        end
    end

endmodule
