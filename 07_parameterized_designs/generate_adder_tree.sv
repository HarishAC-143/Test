// Pipelined adder tree using generate.
// Sums N inputs using a binary tree of adders.
// Each level adds a pipeline register for timing.

module generate_adder_tree #(
    parameter int NUM_INPUTS  = 8,
    parameter int INPUT_WIDTH = 8
)(
    input  logic                                          clk,
    input  logic                                          rst_n,
    input  logic [INPUT_WIDTH-1:0]                        data_in [NUM_INPUTS],
    output logic [INPUT_WIDTH+$clog2(NUM_INPUTS)-1:0]     sum_out
);

    localparam int LEVELS     = $clog2(NUM_INPUTS);
    localparam int OUT_WIDTH  = INPUT_WIDTH + LEVELS;

    // Intermediate results at each level
    // Level 0: NUM_INPUTS values
    // Level k: NUM_INPUTS / 2^k values, each (INPUT_WIDTH + k) bits wide
    logic [OUT_WIDTH-1:0] stage [0:LEVELS][0:NUM_INPUTS-1];

    // Input stage: zero-extend inputs
    genvar i;
    generate
        for (i = 0; i < NUM_INPUTS; i++) begin : gen_input
            assign stage[0][i] = OUT_WIDTH'(data_in[i]);
        end
    endgenerate

    // Tree levels
    genvar lvl, idx;
    generate
        for (lvl = 0; lvl < LEVELS; lvl++) begin : gen_level
            localparam int PAIRS = NUM_INPUTS >> (lvl + 1);

            for (idx = 0; idx < PAIRS; idx++) begin : gen_adder
                always_ff @(posedge clk or negedge rst_n) begin
                    if (!rst_n)
                        stage[lvl+1][idx] <= '0;
                    else
                        stage[lvl+1][idx] <= stage[lvl][2*idx] + stage[lvl][2*idx+1];
                end
            end
        end
    endgenerate

    assign sum_out = stage[LEVELS][0][OUT_WIDTH-1:0];

endmodule
