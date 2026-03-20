// N-bit PWM generator with dead-time insertion.
//
// Features:
// - Configurable resolution (N bits → 2^N duty cycle levels)
// - Complementary outputs with configurable dead time
// - Configurable PWM frequency via prescaler
// - Center-aligned or edge-aligned mode
//
// PWM frequency = clk_freq / (prescaler * 2^N)
// For 100 MHz clock, 8-bit PWM, prescaler=1: PWM freq = 390.625 kHz

module pwm_generator #(
    parameter int RESOLUTION    = 8,     // duty cycle resolution in bits
    parameter int PRESCALER_W   = 8,     // prescaler width
    parameter int DEAD_TIME_W   = 8      // dead-time counter width
)(
    input  logic                     clk,
    input  logic                     rst_n,
    input  logic                     enable,
    input  logic [RESOLUTION-1:0]    duty_cycle,     // 0 = always low, max = always high
    input  logic [PRESCALER_W-1:0]   prescaler,      // clock division (0 = no division)
    input  logic [DEAD_TIME_W-1:0]   dead_time,      // dead-time in clock cycles
    input  logic                     center_aligned,  // 0=edge-aligned, 1=center-aligned

    output logic                     pwm_out,        // main PWM output
    output logic                     pwm_n_out,      // complementary output with dead time
    output logic                     period_start    // pulse at start of each period
);

    // Prescaler counter
    logic [PRESCALER_W-1:0] pre_cnt;
    logic                   pre_tick;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            pre_cnt <= '0;
        else if (!enable)
            pre_cnt <= '0;
        else if (pre_cnt >= prescaler)
            pre_cnt <= '0;
        else
            pre_cnt <= pre_cnt + 1'b1;
    end

    assign pre_tick = enable && (pre_cnt >= prescaler);

    // PWM counter
    logic [RESOLUTION-1:0] pwm_cnt;
    logic                  count_dir;  // 0=up, 1=down (for center-aligned)

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pwm_cnt      <= '0;
            count_dir    <= 1'b0;
            period_start <= 1'b0;
        end else if (!enable) begin
            pwm_cnt      <= '0;
            count_dir    <= 1'b0;
            period_start <= 1'b0;
        end else if (pre_tick) begin
            period_start <= 1'b0;

            if (center_aligned) begin
                if (!count_dir) begin
                    if (pwm_cnt == {RESOLUTION{1'b1}}) begin
                        count_dir <= 1'b1;
                        pwm_cnt   <= pwm_cnt - 1'b1;
                    end else begin
                        pwm_cnt <= pwm_cnt + 1'b1;
                    end
                end else begin
                    if (pwm_cnt == '0) begin
                        count_dir    <= 1'b0;
                        pwm_cnt      <= pwm_cnt + 1'b1;
                        period_start <= 1'b1;
                    end else begin
                        pwm_cnt <= pwm_cnt - 1'b1;
                    end
                end
            end else begin
                if (pwm_cnt == {RESOLUTION{1'b1}}) begin
                    pwm_cnt      <= '0;
                    period_start <= 1'b1;
                end else begin
                    pwm_cnt <= pwm_cnt + 1'b1;
                end
            end
        end else begin
            period_start <= 1'b0;
        end
    end

    // Raw PWM comparison
    logic pwm_raw;
    assign pwm_raw = (pwm_cnt < duty_cycle);

    // Dead-time insertion
    logic [DEAD_TIME_W-1:0] dt_rise_cnt, dt_fall_cnt;
    logic                   pwm_raw_d;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pwm_out     <= 1'b0;
            pwm_n_out   <= 1'b0;
            pwm_raw_d   <= 1'b0;
            dt_rise_cnt <= '0;
            dt_fall_cnt <= '0;
        end else begin
            pwm_raw_d <= pwm_raw;

            // PWM main output: delay rising edges
            if (pwm_raw && !pwm_raw_d) begin
                dt_rise_cnt <= '0;
            end
            if (pwm_raw && dt_rise_cnt < dead_time) begin
                dt_rise_cnt <= dt_rise_cnt + 1'b1;
                pwm_out     <= 1'b0;
            end else begin
                pwm_out <= pwm_raw;
            end

            // Complementary output: delay its rising edges (falling edges of pwm_raw)
            if (!pwm_raw && pwm_raw_d) begin
                dt_fall_cnt <= '0;
            end
            if (!pwm_raw && dt_fall_cnt < dead_time) begin
                dt_fall_cnt <= dt_fall_cnt + 1'b1;
                pwm_n_out   <= 1'b0;
            end else begin
                pwm_n_out <= ~pwm_raw;
            end
        end
    end

endmodule
