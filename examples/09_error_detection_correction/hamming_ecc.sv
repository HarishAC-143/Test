// ----------------------------------------------------------------------------
// Hamming SEC-DED (Single Error Correction, Double Error Detection) Codec
// Demonstrates: parity generation, syndrome decoding, error correction,
//               parameterized data width, generate-based parity trees
// ----------------------------------------------------------------------------

module hamming_encoder #(
    parameter int DATA_BITS = 8
)(
    input  logic [DATA_BITS-1:0]       data_in,
    output logic [DATA_BITS+PARITY_BITS:0] encoded_out  // data + parity + overall parity
);
    // Calculate required parity bits: 2^p >= data + p + 1
    localparam int PARITY_BITS = calc_parity_bits(DATA_BITS);
    localparam int CODE_BITS   = DATA_BITS + PARITY_BITS;

    function automatic int calc_parity_bits(int d);
        int p = 1;
        while ((1 << p) < d + p + 1)
            p++;
        return p;
    endfunction

    logic [CODE_BITS-1:0] code_word;

    // Place data bits in non-power-of-2 positions
    always_comb begin
        code_word = '0;
        begin : place_data
            int d_idx = 0;
            for (int i = 0; i < CODE_BITS; i++) begin
                // Skip power-of-2 positions (parity bit locations)
                if ((i + 1) & i) begin
                    code_word[i] = data_in[d_idx];
                    d_idx++;
                end
            end
        end

        // Generate parity bits
        for (int p = 0; p < PARITY_BITS; p++) begin
            code_word[(1 << p) - 1] = 1'b0;
            for (int i = 0; i < CODE_BITS; i++) begin
                if ((i + 1) & (1 << p))
                    code_word[(1 << p) - 1] ^= code_word[i];
            end
        end

        // Overall parity for double-error detection
        encoded_out = {^code_word, code_word};
    end

endmodule


module hamming_decoder #(
    parameter int DATA_BITS = 8
)(
    input  logic [DATA_BITS+PARITY_BITS:0] encoded_in,
    output logic [DATA_BITS-1:0]           data_out,
    output logic                           single_error,
    output logic                           double_error,
    output logic                           no_error
);

    localparam int PARITY_BITS = calc_parity_bits(DATA_BITS);
    localparam int CODE_BITS   = DATA_BITS + PARITY_BITS;

    function automatic int calc_parity_bits(int d);
        int p = 1;
        while ((1 << p) < d + p + 1)
            p++;
        return p;
    endfunction

    logic [CODE_BITS-1:0]   code_word;
    logic [PARITY_BITS-1:0] syndrome;
    logic                   overall_parity;
    logic [CODE_BITS-1:0]   corrected;

    always_comb begin
        overall_parity = encoded_in[CODE_BITS];
        code_word      = encoded_in[CODE_BITS-1:0];

        // Compute syndrome
        for (int p = 0; p < PARITY_BITS; p++) begin
            syndrome[p] = 1'b0;
            for (int i = 0; i < CODE_BITS; i++) begin
                if ((i + 1) & (1 << p))
                    syndrome[p] ^= code_word[i];
            end
        end

        // Check overall parity
        overall_parity ^= ^code_word;

        // Error classification
        no_error     = (syndrome == '0) &&  !overall_parity;
        single_error = (syndrome != '0) &&   overall_parity;
        double_error = (syndrome != '0) &&  !overall_parity;

        // Correct single-bit error
        corrected = code_word;
        if (single_error && syndrome <= CODE_BITS)
            corrected[syndrome - 1] = ~code_word[syndrome - 1];

        // Extract data bits from corrected codeword
        data_out = '0;
        begin : extract_data
            int d_idx = 0;
            for (int i = 0; i < CODE_BITS; i++) begin
                if ((i + 1) & i) begin
                    data_out[d_idx] = corrected[i];
                    d_idx++;
                end
            end
        end
    end

endmodule
