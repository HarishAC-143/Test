// =============================================================================
// SpyGlass CDC Example: MUX-Based Data Synchronization (Handshake)
// =============================================================================
//
// Transfers a multi-bit data bus across clock domains using a
// request/acknowledge handshake protocol with MUX synchronization.
//
// The data bus is held stable in the source domain while a synchronized
// control signal tells the destination domain when the data is valid.
// The destination acknowledges receipt, and only then can new data
// be sent.
//
// This avoids the multi-bit CDC problem because the data bus does NOT
// cross through synchronizer flip-flops — only the control signals do.
//
//   clk_a domain:                   clk_b domain:
//   data_bus ──────────────────────▶ data_out (MUX-captured)
//   req ──────▶ [2FF sync] ────────▶ req_sync → captures data
//   ack_sync ◀──── [2FF sync] ◀──── ack
//
// Run with: current_goal cdc/cdc_verify
// =============================================================================

module mux_sync #(
    parameter DATA_WIDTH = 8
)(
    // Source domain (clk_a)
    input                    clk_a,
    input                    rst_a_n,
    input  [DATA_WIDTH-1:0]  data_in,
    input                    data_valid,   // Pulse: new data available
    output                   ready,        // High when ready for new data

    // Destination domain (clk_b)
    input                    clk_b,
    input                    rst_b_n,
    output reg [DATA_WIDTH-1:0] data_out,
    output reg               data_out_valid
);

    // =========================================================================
    // Source Domain (clk_a): Hold data and generate request
    // =========================================================================
    reg [DATA_WIDTH-1:0] data_hold;
    reg                  req_toggle;

    // Synchronize ack back into clk_a domain
    reg ack_sync1, ack_sync2, ack_sync3;
    wire ack_toggle_b;

    always @(posedge clk_a or negedge rst_a_n) begin
        if (!rst_a_n) begin
            ack_sync1 <= 1'b0;
            ack_sync2 <= 1'b0;
            ack_sync3 <= 1'b0;
        end else begin
            ack_sync1 <= ack_toggle_b;
            ack_sync2 <= ack_sync1;
            ack_sync3 <= ack_sync2;
        end
    end

    // Ready when req_toggle == ack (handshake complete)
    wire handshake_idle = (req_toggle == ack_sync2);
    assign ready = handshake_idle;

    always @(posedge clk_a or negedge rst_a_n) begin
        if (!rst_a_n) begin
            data_hold  <= {DATA_WIDTH{1'b0}};
            req_toggle <= 1'b0;
        end else if (data_valid && handshake_idle) begin
            data_hold  <= data_in;
            req_toggle <= ~req_toggle;  // Toggle to signal new data
        end
    end

    // =========================================================================
    // Synchronize request into clk_b domain
    // =========================================================================
    reg req_sync1, req_sync2, req_sync3;

    always @(posedge clk_b or negedge rst_b_n) begin
        if (!rst_b_n) begin
            req_sync1 <= 1'b0;
            req_sync2 <= 1'b0;
            req_sync3 <= 1'b0;
        end else begin
            req_sync1 <= req_toggle;
            req_sync2 <= req_sync1;
            req_sync3 <= req_sync2;
        end
    end

    // Detect request edge in clk_b domain
    wire req_pulse = req_sync2 ^ req_sync3;

    // =========================================================================
    // Destination Domain (clk_b): Capture data and acknowledge
    // =========================================================================
    reg ack_toggle;
    assign ack_toggle_b = ack_toggle;

    always @(posedge clk_b or negedge rst_b_n) begin
        if (!rst_b_n) begin
            data_out       <= {DATA_WIDTH{1'b0}};
            data_out_valid <= 1'b0;
            ack_toggle     <= 1'b0;
        end else begin
            data_out_valid <= 1'b0;

            if (req_pulse) begin
                // Data bus is stable (held by source domain), safe to sample
                data_out       <= data_hold;
                data_out_valid <= 1'b1;
                ack_toggle     <= ~ack_toggle;
            end
        end
    end

endmodule
