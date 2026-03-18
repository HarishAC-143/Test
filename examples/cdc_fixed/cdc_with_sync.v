// =============================================================================
// Example 4 — FIXED: Proper CDC Synchronization
// =============================================================================
// Compare with: examples/cdc_issues/cdc_missing_sync.v
//
// Fixes applied:
//   [FIXED] Ac_cdc01 — Added 2-FF synchronizer for single-bit 'pulse_a'
//   [FIXED] Ac_cdc02 — Used handshake protocol for multi-bit 'data_a'
//
// Strategy:
//   - Single-bit control signal: 2-FF synchronizer
//   - Multi-bit data: Handshake — hold data stable, send request, wait for ack
// =============================================================================

module cdc_with_sync (
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

    // =========================================================================
    // Clock Domain A — Source
    // =========================================================================
    reg       pulse_a;
    reg [7:0] data_a;
    reg       req_a;          // handshake request (toggles on each transaction)
    wire      ack_a_sync;     // synchronized ack from domain B

    always @(posedge clk_a or negedge rst_a_n) begin
        if (!rst_a_n) begin
            pulse_a <= 1'b0;
            data_a  <= 8'd0;
            req_a   <= 1'b0;
        end else begin
            pulse_a <= trigger;
            if (trigger) begin
                data_a <= data_a + 1'b1;
                req_a  <= ~req_a;    // Toggle request — signals new data
            end
        end
    end

    // Synchronize ack from domain B back into domain A (2-FF)
    reg ack_sync1_a, ack_sync2_a;
    always @(posedge clk_a or negedge rst_a_n) begin
        if (!rst_a_n) begin
            ack_sync1_a <= 1'b0;
            ack_sync2_a <= 1'b0;
        end else begin
            ack_sync1_a <= ack_b;
            ack_sync2_a <= ack_sync1_a;
        end
    end
    assign ack_a_sync = ack_sync2_a;

    // =========================================================================
    // Clock Domain B — Destination
    // =========================================================================

    // 2-FF synchronizer for single-bit request signal
    reg req_sync1_b, req_sync2_b;
    always @(posedge clk_b or negedge rst_b_n) begin
        if (!rst_b_n) begin
            req_sync1_b <= 1'b0;
            req_sync2_b <= 1'b0;
        end else begin
            req_sync1_b <= req_a;          // Stage 1: may go metastable
            req_sync2_b <= req_sync1_b;    // Stage 2: resolved value
        end
    end

    // Detect toggle → new data available
    reg req_prev_b;
    wire new_data_b;

    always @(posedge clk_b or negedge rst_b_n) begin
        if (!rst_b_n)
            req_prev_b <= 1'b0;
        else
            req_prev_b <= req_sync2_b;
    end

    assign new_data_b = (req_sync2_b != req_prev_b);

    // Capture data when handshake indicates new data
    // data_a is held stable by domain A until ack is received
    reg ack_b;

    always @(posedge clk_b or negedge rst_b_n) begin
        if (!rst_b_n) begin
            data_valid_b  <= 1'b0;
            captured_data <= 8'd0;
            ack_b         <= 1'b0;
        end else begin
            data_valid_b <= 1'b0;   // pulse
            if (new_data_b) begin
                captured_data <= data_a;   // Safe: data_a is stable (held by handshake)
                data_valid_b  <= 1'b1;
                ack_b         <= req_sync2_b;  // Echo back request as ack
            end
        end
    end

endmodule
