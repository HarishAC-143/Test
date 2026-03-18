// =============================================================================
// Example 4: CDC — Missing Synchronizer
// =============================================================================
// A signal generated in clk_a domain is directly used in clk_b domain
// without any synchronization. This is the most common CDC violation.
//
// SpyGlass CDC will report:
//   Ac_cdc01 — "Signal 'pulse_a' crosses from clock domain 'clk_a' to
//               clock domain 'clk_b' without synchronization."
//
// Risk: Metastability on 'data_valid_b'. The receiving flip-flop may
// capture an indeterminate value, causing intermittent failures.
// =============================================================================

module cdc_missing_sync (
    // Domain A
    input  wire       clk_a,
    input  wire       rst_a_n,
    input  wire       trigger,

    // Domain B
    input  wire       clk_b,
    input  wire       rst_b_n,
    output reg        data_valid_b,
    output reg [7:0]  captured_data
);

    // ----- Clock Domain A -----
    reg pulse_a;
    reg [7:0] data_a;

    always @(posedge clk_a or negedge rst_a_n) begin
        if (!rst_a_n) begin
            pulse_a <= 1'b0;
            data_a  <= 8'd0;
        end else begin
            pulse_a <= trigger;
            if (trigger)
                data_a <= data_a + 1'b1;
        end
    end

    // ----- Clock Domain B -----

    // BUG: Direct use of clk_a-domain signal 'pulse_a' in clk_b domain.
    // No synchronizer exists between the two domains.
    //
    // What happens in hardware:
    //   1. pulse_a transitions on clk_a rising edge
    //   2. If this transition occurs near clk_b's rising edge,
    //      the setup/hold time of the clk_b flip-flop is violated
    //   3. data_valid_b enters a metastable state
    //   4. Downstream logic sees an unpredictable value
    always @(posedge clk_b or negedge rst_b_n) begin
        if (!rst_b_n) begin
            data_valid_b <= 1'b0;
            captured_data <= 8'd0;
        end else begin
            data_valid_b <= pulse_a;       // VIOLATION: Ac_cdc01
            if (pulse_a)                   // VIOLATION: Ac_cdc01
                captured_data <= data_a;   // VIOLATION: Ac_cdc02 (multi-bit)
        end
    end

endmodule
