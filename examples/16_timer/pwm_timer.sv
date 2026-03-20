// ============================================================================
// Multi-Channel PWM Timer
// ============================================================================
// A general-purpose hardware timer with multiple PWM output channels.
// Applications: LED dimming, motor speed control, servo positioning,
// audio tone generation.
//
// Features:
//   - Configurable counter width and number of channels
//   - Software-programmable period and per-channel duty cycle
//   - Overflow interrupt output
//   - Enable/disable control
//
// Each PWM output is high when counter < duty[ch], giving a duty cycle
// of duty[ch] / period.
// ============================================================================

module pwm_timer #(
    parameter int WIDTH        = 16,
    parameter int NUM_CHANNELS = 4
)(
    input  logic             clk,
    input  logic             rst_n,
    input  logic             enable,
    input  logic [WIDTH-1:0] period,
    input  logic [WIDTH-1:0] duty [NUM_CHANNELS],
    output logic [NUM_CHANNELS-1:0] pwm_out,
    output logic             overflow
);

    logic [WIDTH-1:0] counter;

    // Free-running counter with configurable period
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            counter <= '0;
        else if (enable) begin
            if (counter >= period)
                counter <= '0;
            else
                counter <= counter + 1'b1;
        end
    end

    // Overflow pulse
    assign overflow = enable && (counter == period);

    // PWM comparison — one output per channel
    genvar ch;
    generate
        for (ch = 0; ch < NUM_CHANNELS; ch++) begin : gen_pwm
            assign pwm_out[ch] = (counter < duty[ch]);
        end
    endgenerate

endmodule


// ============================================================================
// Watchdog Timer
// ============================================================================
// Counts down from a programmable value. If not kicked (reloaded) before
// reaching zero, it asserts the timeout signal. Used for system health
// monitoring in embedded FPGA designs.
// ============================================================================

module watchdog_timer #(
    parameter int WIDTH = 24
)(
    input  logic             clk,
    input  logic             rst_n,
    input  logic             enable,
    input  logic             kick,        // reload the counter
    input  logic [WIDTH-1:0] timeout_val, // reload value
    output logic             timeout      // asserted on expiry
);

    logic [WIDTH-1:0] counter;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            counter <= '1;  // max value after reset
            timeout <= 1'b0;
        end else if (kick) begin
            counter <= timeout_val;
            timeout <= 1'b0;
        end else if (enable) begin
            if (counter == '0)
                timeout <= 1'b1;
            else
                counter <= counter - 1'b1;
        end
    end

endmodule
