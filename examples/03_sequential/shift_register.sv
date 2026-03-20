// Shift Register Implementations
// Demonstrates serial-in/parallel-out, parallel-in/serial-out, and barrel shifter

// Serial-In, Parallel-Out (SIPO) Shift Register
module sipo_shift_reg #(
    parameter int WIDTH = 8
) (
    input  logic             clk,
    input  logic             rst_n,
    input  logic             shift_en,
    input  logic             serial_in,
    output logic [WIDTH-1:0] parallel_out,
    output logic             serial_out
);
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            parallel_out <= '0;
        else if (shift_en)
            parallel_out <= {parallel_out[WIDTH-2:0], serial_in};
    end

    assign serial_out = parallel_out[WIDTH-1];
endmodule


// Parallel-In, Serial-Out (PISO) Shift Register
module piso_shift_reg #(
    parameter int WIDTH = 8
) (
    input  logic             clk,
    input  logic             rst_n,
    input  logic             load,
    input  logic             shift_en,
    input  logic [WIDTH-1:0] parallel_in,
    output logic             serial_out
);
    logic [WIDTH-1:0] shift_reg;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            shift_reg <= '0;
        else if (load)
            shift_reg <= parallel_in;
        else if (shift_en)
            shift_reg <= {shift_reg[WIDTH-2:0], 1'b0};
    end

    assign serial_out = shift_reg[WIDTH-1];
endmodule


// Linear Feedback Shift Register (LFSR) - pseudo-random number generator
// Uses Fibonacci configuration with taps for maximal-length sequence
module lfsr #(
    parameter int WIDTH = 8,
    parameter logic [WIDTH-1:0] SEED = 8'hAC  // Non-zero seed
) (
    input  logic             clk,
    input  logic             rst_n,
    input  logic             enable,
    output logic [WIDTH-1:0] lfsr_out
);
    logic feedback;

    // Feedback taps for 8-bit LFSR: x^8 + x^6 + x^5 + x^4 + 1
    assign feedback = lfsr_out[7] ^ lfsr_out[5] ^ lfsr_out[4] ^ lfsr_out[3];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            lfsr_out <= SEED;
        else if (enable)
            lfsr_out <= {lfsr_out[WIDTH-2:0], feedback};
    end
endmodule
