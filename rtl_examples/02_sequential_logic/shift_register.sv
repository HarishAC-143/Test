// =============================================================================
// Universal Shift Register
// Supports: hold, shift left, shift right, and parallel load.
// =============================================================================

module universal_shift_register #(
    parameter WIDTH = 8
) (
    input  logic              clk,
    input  logic              rst_n,
    input  logic [1:0]        mode,       // 00=hold, 01=shift right, 10=shift left, 11=parallel load
    input  logic              serial_in_l, // Serial input for left shift (enters at LSB)
    input  logic              serial_in_r, // Serial input for right shift (enters at MSB)
    input  logic [WIDTH-1:0]  parallel_in,
    output logic [WIDTH-1:0]  data_out,
    output logic              serial_out_l, // Serial output from MSB
    output logic              serial_out_r  // Serial output from LSB
);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_out <= '0;
        end else begin
            case (mode)
                2'b00: data_out <= data_out;                                 // Hold
                2'b01: data_out <= {serial_in_r, data_out[WIDTH-1:1]};       // Shift right
                2'b10: data_out <= {data_out[WIDTH-2:0], serial_in_l};       // Shift left
                2'b11: data_out <= parallel_in;                              // Parallel load
            endcase
        end
    end

    assign serial_out_l = data_out[WIDTH-1];
    assign serial_out_r = data_out[0];

endmodule

// =============================================================================
// Linear Feedback Shift Register (LFSR) — Galois Configuration
// Generates pseudo-random sequences. Polynomial is parameterized.
// Default: x^8 + x^6 + x^5 + x^4 + 1 (maximal-length for 8-bit)
// =============================================================================

module lfsr_galois #(
    parameter WIDTH = 8,
    parameter logic [WIDTH-1:0] POLYNOMIAL = 8'b10110100,
    parameter logic [WIDTH-1:0] SEED       = 8'b00000001
) (
    input  logic              clk,
    input  logic              rst_n,
    input  logic              enable,
    output logic [WIDTH-1:0]  lfsr_out,
    output logic              feedback_bit
);

    assign feedback_bit = lfsr_out[0];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            lfsr_out <= SEED;
        end else if (enable) begin
            if (feedback_bit)
                lfsr_out <= (lfsr_out >> 1) ^ POLYNOMIAL;
            else
                lfsr_out <= lfsr_out >> 1;
        end
    end

endmodule
