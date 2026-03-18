// ----------------------------------------------------------------------------
// Parameterized FIR (Finite Impulse Response) Filter
// Demonstrates: systolic architecture, fixed-point arithmetic,
//               configurable taps, coefficient loading, pipelined MAC
// ----------------------------------------------------------------------------

module fir_filter #(
    parameter int DATA_WIDTH  = 16,
    parameter int COEFF_WIDTH = 16,
    parameter int NUM_TAPS    = 8,
    parameter int OUT_WIDTH   = DATA_WIDTH + COEFF_WIDTH + $clog2(NUM_TAPS)
)(
    input  logic                       clk,
    input  logic                       rst_n,

    // Data interface
    input  logic signed [DATA_WIDTH-1:0]  data_in,
    input  logic                          data_valid,
    output logic signed [OUT_WIDTH-1:0]   data_out,
    output logic                          out_valid,

    // Coefficient loading interface
    input  logic signed [COEFF_WIDTH-1:0] coeff_data,
    input  logic [$clog2(NUM_TAPS)-1:0]   coeff_addr,
    input  logic                          coeff_wr
);

    // Coefficient storage
    logic signed [COEFF_WIDTH-1:0] coefficients [NUM_TAPS];

    // Delay line (tapped delay)
    logic signed [DATA_WIDTH-1:0] delay_line [NUM_TAPS];

    // Product and accumulator
    logic signed [DATA_WIDTH+COEFF_WIDTH-1:0] products [NUM_TAPS];
    logic signed [OUT_WIDTH-1:0]              acc;

    // Pipeline valid tracking
    logic valid_d1, valid_d2;

    // Coefficient loading
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < NUM_TAPS; i++)
                coefficients[i] <= '0;
        end else if (coeff_wr) begin
            coefficients[coeff_addr] <= coeff_data;
        end
    end

    // Shift register (delay line)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < NUM_TAPS; i++)
                delay_line[i] <= '0;
        end else if (data_valid) begin
            delay_line[0] <= data_in;
            for (int i = 1; i < NUM_TAPS; i++)
                delay_line[i] <= delay_line[i-1];
        end
    end

    // Stage 1: Parallel multiply
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < NUM_TAPS; i++)
                products[i] <= '0;
            valid_d1 <= 1'b0;
        end else begin
            valid_d1 <= data_valid;
            if (data_valid) begin
                for (int i = 0; i < NUM_TAPS; i++)
                    products[i] <= delay_line[i] * coefficients[i];
            end
        end
    end

    // Stage 2: Adder tree (accumulate all products)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            acc      <= '0;
            valid_d2 <= 1'b0;
        end else begin
            valid_d2 <= valid_d1;
            if (valid_d1) begin
                acc <= '0;
                for (int i = 0; i < NUM_TAPS; i++)
                    acc <= acc + OUT_WIDTH'(products[i]);
            end
        end
    end

    assign data_out  = acc;
    assign out_valid = valid_d2;

endmodule
