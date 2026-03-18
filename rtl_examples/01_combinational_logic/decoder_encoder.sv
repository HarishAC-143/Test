// =============================================================================
// Parameterized Binary Decoder (N-to-2^N)
// =============================================================================

module binary_decoder #(
    parameter INPUT_WIDTH  = 3,
    parameter OUTPUT_WIDTH = 1 << INPUT_WIDTH
) (
    input  logic [INPUT_WIDTH-1:0]  encoded,
    input  logic                    enable,
    output logic [OUTPUT_WIDTH-1:0] decoded
);

    always_comb begin
        decoded = '0;
        if (enable)
            decoded[encoded] = 1'b1;
    end

endmodule

// =============================================================================
// One-Hot to Binary Encoder
// =============================================================================

module onehot_to_binary #(
    parameter NUM_INPUTS  = 8,
    parameter INDEX_WIDTH = $clog2(NUM_INPUTS)
) (
    input  logic [NUM_INPUTS-1:0]   onehot,
    output logic [INDEX_WIDTH-1:0]  binary,
    output logic                    valid
);

    always_comb begin
        binary = '0;
        valid  = 1'b0;

        for (int i = 0; i < NUM_INPUTS; i++) begin
            if (onehot[i]) begin
                binary = binary | INDEX_WIDTH'(i);
                valid  = 1'b1;
            end
        end
    end

    // Assertion: input should be one-hot when valid
    // synthesis translate_off
    always_comb begin
        if (valid) begin
            assert ($onehot(onehot)) else
                $error("Input is not one-hot: %b", onehot);
        end
    end
    // synthesis translate_on

endmodule

// =============================================================================
// Parameterized Multiplexer using one-hot select
// =============================================================================

module mux_onehot #(
    parameter NUM_INPUTS  = 4,
    parameter DATA_WIDTH  = 32
) (
    input  logic [NUM_INPUTS-1:0]                select,
    input  logic [NUM_INPUTS-1:0][DATA_WIDTH-1:0] data_in,
    output logic [DATA_WIDTH-1:0]                data_out
);

    always_comb begin
        data_out = '0;
        for (int i = 0; i < NUM_INPUTS; i++) begin
            if (select[i])
                data_out = data_out | data_in[i];
        end
    end

endmodule
