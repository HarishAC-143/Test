// ----------------------------------------------------------------------------
// Parameterized Crossbar Switch Using Generate Statements
// Demonstrates: generate for/if, parameter arrays, interfaces, modport
// ----------------------------------------------------------------------------

interface crossbar_if #(
    parameter int DATA_WIDTH = 32
);
    logic [DATA_WIDTH-1:0] data;
    logic                  valid;
    logic                  ready;

    modport master (
        output data, valid,
        input  ready
    );

    modport slave (
        input  data, valid,
        output ready
    );
endinterface

module crossbar_switch #(
    parameter int NUM_MASTERS = 4,
    parameter int NUM_SLAVES  = 4,
    parameter int DATA_WIDTH  = 32,
    parameter int SEL_WIDTH   = $clog2(NUM_SLAVES)
)(
    input  logic                            clk,
    input  logic                            rst_n,
    input  logic [SEL_WIDTH-1:0]            route_sel [NUM_MASTERS],
    input  logic [DATA_WIDTH-1:0]           master_data  [NUM_MASTERS],
    input  logic                            master_valid [NUM_MASTERS],
    output logic                            master_ready [NUM_MASTERS],
    output logic [DATA_WIDTH-1:0]           slave_data   [NUM_SLAVES],
    output logic                            slave_valid  [NUM_SLAVES],
    input  logic                            slave_ready  [NUM_SLAVES]
);

    // Per-slave grant signals from arbitration
    logic [NUM_MASTERS-1:0] request  [NUM_SLAVES];
    logic [NUM_MASTERS-1:0] grant    [NUM_SLAVES];

    // Build per-slave request vectors
    generate
        for (genvar s = 0; s < NUM_SLAVES; s++) begin : gen_request
            for (genvar m = 0; m < NUM_MASTERS; m++) begin : gen_req_bit
                assign request[s][m] = master_valid[m] && (route_sel[m] == s[SEL_WIDTH-1:0]);
            end
        end
    endgenerate

    // Round-robin arbiter per slave port
    generate
        for (genvar s = 0; s < NUM_SLAVES; s++) begin : gen_arbiter
            round_robin_arbiter #(
                .NUM_REQUESTORS(NUM_MASTERS)
            ) u_arb (
                .clk     (clk),
                .rst_n   (rst_n),
                .request (request[s]),
                .grant   (grant[s])
            );
        end
    endgenerate

    // Mux data and valid to slave ports based on grant
    generate
        for (genvar s = 0; s < NUM_SLAVES; s++) begin : gen_slave_mux
            always_comb begin
                slave_data[s]  = '0;
                slave_valid[s] = 1'b0;
                for (int m = 0; m < NUM_MASTERS; m++) begin
                    if (grant[s][m]) begin
                        slave_data[s]  = master_data[m];
                        slave_valid[s] = 1'b1;
                    end
                end
            end
        end
    endgenerate

    // Route ready signals back to masters
    generate
        for (genvar m = 0; m < NUM_MASTERS; m++) begin : gen_master_ready
            always_comb begin
                master_ready[m] = 1'b0;
                for (int s = 0; s < NUM_SLAVES; s++) begin
                    if (grant[s][m])
                        master_ready[m] = slave_ready[s];
                end
            end
        end
    endgenerate

endmodule

// Simple round-robin arbiter used by the crossbar
module round_robin_arbiter #(
    parameter int NUM_REQUESTORS = 4
)(
    input  logic                       clk,
    input  logic                       rst_n,
    input  logic [NUM_REQUESTORS-1:0]  request,
    output logic [NUM_REQUESTORS-1:0]  grant
);

    logic [NUM_REQUESTORS-1:0] priority_mask;
    logic [NUM_REQUESTORS-1:0] masked_request;
    logic [NUM_REQUESTORS-1:0] unmasked_grant;
    logic [NUM_REQUESTORS-1:0] masked_grant;
    logic                      use_masked;

    // Mask requests below the last granted priority
    assign masked_request = request & priority_mask;
    assign use_masked     = |masked_request;

    // Priority encoder for masked and unmasked requests
    always_comb begin
        masked_grant   = '0;
        unmasked_grant = '0;

        // Masked: find lowest-set bit
        for (int i = 0; i < NUM_REQUESTORS; i++) begin
            if (masked_request[i] && masked_grant == '0)
                masked_grant[i] = 1'b1;
        end

        // Unmasked: find lowest-set bit
        for (int i = 0; i < NUM_REQUESTORS; i++) begin
            if (request[i] && unmasked_grant == '0)
                unmasked_grant[i] = 1'b1;
        end
    end

    assign grant = use_masked ? masked_grant : unmasked_grant;

    // Update priority mask after each grant
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            priority_mask <= '1;
        end else if (|grant) begin
            // Shift mask to disable the granted requestor and all lower
            for (int i = 0; i < NUM_REQUESTORS; i++) begin
                if (grant[i])
                    priority_mask <= ({NUM_REQUESTORS{1'b1}} << (i + 1));
            end
        end
    end

endmodule
