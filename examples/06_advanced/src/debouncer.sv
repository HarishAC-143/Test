// Button Debouncer
// Filters mechanical switch bounce by requiring the input to be
// stable for STABLE_TICKS consecutive clock cycles before accepting
// the new value. Outputs a clean, debounced signal and single-cycle
// edge pulses.

module debouncer #(
    parameter STABLE_TICKS = 1_000_000,  // ~20ms at 50MHz
    parameter CNT_WIDTH    = $clog2(STABLE_TICKS + 1)
)(
    input  logic clk,
    input  logic rst_n,
    input  logic noisy_in,
    output logic clean_out,
    output logic rising_pulse,
    output logic falling_pulse
);

    logic [CNT_WIDTH-1:0] cnt;
    logic                 noisy_sync;
    logic                 clean_d;

    // Two-flop synchronizer for the asynchronous button input
    logic noisy_meta;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            noisy_meta <= 1'b0;
            noisy_sync <= 1'b0;
        end else begin
            noisy_meta <= noisy_in;
            noisy_sync <= noisy_meta;
        end
    end

    // Stability counter
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt       <= '0;
            clean_out <= 1'b0;
        end else begin
            if (noisy_sync != clean_out) begin
                if (cnt == STABLE_TICKS[CNT_WIDTH-1:0] - 1) begin
                    clean_out <= noisy_sync;
                    cnt       <= '0;
                end else begin
                    cnt <= cnt + 1'b1;
                end
            end else begin
                cnt <= '0;
            end
        end
    end

    // Edge detection on clean signal
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            clean_d <= 1'b0;
        else
            clean_d <= clean_out;
    end

    assign rising_pulse  = clean_out & ~clean_d;
    assign falling_pulse = ~clean_out & clean_d;

endmodule
