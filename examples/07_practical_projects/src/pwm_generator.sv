// PWM Generator
// Produces a pulse-width modulated output signal.
// Resolution is set by COUNTER_WIDTH; duty cycle is set by the duty input.
// Frequency: f_pwm = f_clk / (2^COUNTER_WIDTH).
// Example: 50MHz clk, 8-bit counter -> ~195kHz PWM frequency.

module pwm_generator #(
    parameter COUNTER_WIDTH = 8
)(
    input  logic                       clk,
    input  logic                       rst_n,
    input  logic                       enable,
    input  logic [COUNTER_WIDTH-1:0]   duty,    // 0 = always low, max = always high
    output logic                       pwm_out
);

    logic [COUNTER_WIDTH-1:0] counter;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            counter <= '0;
        else if (enable)
            counter <= counter + 1'b1;
    end

    // Comparator: output high when counter < duty
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            pwm_out <= 1'b0;
        else if (enable)
            pwm_out <= (counter < duty);
        else
            pwm_out <= 1'b0;
    end

endmodule
