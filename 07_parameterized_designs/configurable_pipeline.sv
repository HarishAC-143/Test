// Configurable N-stage pipeline register.
// Useful for retiming, latency matching, or register balancing.
// NUM_STAGES = 0 means direct pass-through (wire).

module configurable_pipeline #(
    parameter int WIDTH      = 32,
    parameter int NUM_STAGES = 3
)(
    input  logic             clk,
    input  logic             rst_n,
    input  logic [WIDTH-1:0] data_in,
    input  logic             valid_in,
    output logic [WIDTH-1:0] data_out,
    output logic             valid_out
);

    generate
        if (NUM_STAGES == 0) begin : gen_passthrough

            assign data_out  = data_in;
            assign valid_out = valid_in;

        end else begin : gen_pipeline

            logic [WIDTH-1:0] pipe_data  [0:NUM_STAGES-1];
            logic             pipe_valid [0:NUM_STAGES-1];

            // First stage
            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    pipe_data[0]  <= '0;
                    pipe_valid[0] <= 1'b0;
                end else begin
                    pipe_data[0]  <= data_in;
                    pipe_valid[0] <= valid_in;
                end
            end

            // Subsequent stages
            for (genvar i = 1; i < NUM_STAGES; i++) begin : gen_stage
                always_ff @(posedge clk or negedge rst_n) begin
                    if (!rst_n) begin
                        pipe_data[i]  <= '0;
                        pipe_valid[i] <= 1'b0;
                    end else begin
                        pipe_data[i]  <= pipe_data[i-1];
                        pipe_valid[i] <= pipe_valid[i-1];
                    end
                end
            end

            assign data_out  = pipe_data[NUM_STAGES-1];
            assign valid_out = pipe_valid[NUM_STAGES-1];

        end
    endgenerate

endmodule
