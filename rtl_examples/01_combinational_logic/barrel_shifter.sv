// =============================================================================
// Parameterized Barrel Shifter
// Performs left/right logical and arithmetic shifts in a single cycle
// using a logarithmic cascade of multiplexers.
// =============================================================================

module barrel_shifter #(
    parameter DATA_WIDTH  = 32,
    parameter SHIFT_WIDTH = $clog2(DATA_WIDTH)
) (
    input  logic [DATA_WIDTH-1:0]   data_in,
    input  logic [SHIFT_WIDTH-1:0]  shift_amount,
    input  logic                    shift_right,
    input  logic                    arithmetic,
    output logic [DATA_WIDTH-1:0]   data_out
);

    logic [DATA_WIDTH-1:0] stage [SHIFT_WIDTH+1];
    logic fill_bit;

    assign fill_bit = arithmetic & shift_right & data_in[DATA_WIDTH-1];

    // Logarithmic shift stages — each stage conditionally shifts by 2^i
    always_comb begin
        if (shift_right)
            stage[0] = data_in;
        else
            stage[0] = reverse_bits(data_in);

        for (int i = 0; i < SHIFT_WIDTH; i++) begin
            if (shift_amount[i]) begin
                stage[i+1] = {{(1 << i){fill_bit}}, stage[i][DATA_WIDTH-1:(1 << i)]};
            end else begin
                stage[i+1] = stage[i];
            end
        end
    end

    assign data_out = shift_right ? stage[SHIFT_WIDTH] : reverse_bits(stage[SHIFT_WIDTH]);

    function automatic logic [DATA_WIDTH-1:0] reverse_bits(input logic [DATA_WIDTH-1:0] in);
        logic [DATA_WIDTH-1:0] out;
        for (int i = 0; i < DATA_WIDTH; i++)
            out[i] = in[DATA_WIDTH-1-i];
        return out;
    endfunction

endmodule
