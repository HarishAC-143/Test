// =============================================================================
// Watchdog Timer
// Generates a system reset if software fails to "kick" the timer
// within the configured timeout period. Includes two-stage warning.
// =============================================================================

module watchdog_timer #(
    parameter WIDTH       = 24,           // Counter width
    parameter WARN_THRESH = 24'hC00000    // Warning threshold (75% of max)
) (
    input  logic              clk,
    input  logic              rst_n,
    input  logic              enable,
    input  logic              kick,         // Software resets the counter
    input  logic [WIDTH-1:0]  timeout_val,  // Configurable timeout value
    output logic              warning,      // Early warning
    output logic              timeout,      // Timeout occurred — trigger reset
    output logic [WIDTH-1:0]  count_val     // Current counter value (debug)
);

    logic [WIDTH-1:0] counter;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            counter <= '0;
            timeout <= 1'b0;
        end else if (!enable) begin
            counter <= '0;
            timeout <= 1'b0;
        end else if (kick) begin
            counter <= '0;
            timeout <= 1'b0;
        end else if (counter >= timeout_val) begin
            timeout <= 1'b1;
        end else begin
            counter <= counter + 1'b1;
        end
    end

    assign warning   = enable && (counter >= WARN_THRESH) && !timeout;
    assign count_val = counter;

endmodule
