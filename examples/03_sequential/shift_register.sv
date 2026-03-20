// ============================================================================
// Parameterized Shift Register
// ============================================================================
// N-stage shift register with configurable width. Supports shift enable
// and parallel load. Commonly used for serial-to-parallel conversion,
// delay lines, and data alignment.
// ============================================================================

module shift_register #(
    parameter int WIDTH = 8,
    parameter int DEPTH = 4
)(
    input  logic             clk,
    input  logic             rst_n,
    input  logic             shift_en,
    input  logic             load,
    input  logic [WIDTH-1:0] data_in,
    input  logic [WIDTH-1:0] parallel_in [DEPTH],
    output logic [WIDTH-1:0] data_out,
    output logic [WIDTH-1:0] parallel_out [DEPTH]
);

    logic [WIDTH-1:0] stage [DEPTH];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < DEPTH; i++)
                stage[i] <= '0;
        end else if (load) begin
            for (int i = 0; i < DEPTH; i++)
                stage[i] <= parallel_in[i];
        end else if (shift_en) begin
            stage[0] <= data_in;
            for (int i = 1; i < DEPTH; i++)
                stage[i] <= stage[i-1];
        end
    end

    assign data_out = stage[DEPTH-1];

    always_comb begin
        for (int i = 0; i < DEPTH; i++)
            parallel_out[i] = stage[i];
    end

endmodule
