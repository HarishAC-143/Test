// =============================================================================
// PWM Generator with Dead-Time Control
// Generates complementary PWM signals for motor control / power electronics.
// Configurable resolution, frequency, and dead-time insertion.
// =============================================================================

module pwm_generator #(
    parameter RESOLUTION  = 10,  // Bits of PWM resolution (2^10 = 1024 levels)
    parameter DEAD_TIME   = 5    // Dead-time in clock cycles
) (
    input  logic                    clk,
    input  logic                    rst_n,
    input  logic                    enable,
    input  logic [RESOLUTION-1:0]   duty_cycle,  // 0 = 0%, all 1s = 100%
    output logic                    pwm_out,
    output logic                    pwm_out_n,   // Complementary output with dead-time
    output logic                    cycle_done
);

    logic [RESOLUTION-1:0] counter;
    logic pwm_raw;
    logic pwm_raw_prev;
    logic [$clog2(DEAD_TIME+1)-1:0] dead_counter;

    // Free-running counter
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            counter <= '0;
        else if (enable)
            counter <= counter + 1'b1;
    end

    assign cycle_done = enable && (&counter);

    // Raw PWM comparison
    assign pwm_raw = (counter < duty_cycle);

    // Dead-time insertion state machine
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pwm_out      <= 1'b0;
            pwm_out_n    <= 1'b0;
            dead_counter <= '0;
            pwm_raw_prev <= 1'b0;
        end else if (enable) begin
            pwm_raw_prev <= pwm_raw;

            if (pwm_raw != pwm_raw_prev) begin
                // Transition detected — start dead-time
                pwm_out   <= 1'b0;
                pwm_out_n <= 1'b0;
                dead_counter <= DEAD_TIME[$clog2(DEAD_TIME+1)-1:0];
            end else if (dead_counter > 0) begin
                dead_counter <= dead_counter - 1'b1;
                pwm_out   <= 1'b0;
                pwm_out_n <= 1'b0;
            end else begin
                pwm_out   <= pwm_raw;
                pwm_out_n <= ~pwm_raw;
            end
        end
    end

endmodule
