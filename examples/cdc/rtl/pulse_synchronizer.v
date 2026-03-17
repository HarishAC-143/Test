// =============================================================================
// Pulse Synchronizer
// =============================================================================
// Transfers a single-cycle pulse from the source clock domain to the
// destination clock domain, producing a single-cycle pulse in the destination.
//
// Technique: Toggle-based synchronization
//   1. Source domain: pulse toggles a flip-flop
//   2. Toggled level is synchronized through a 2-FF synchronizer
//   3. Destination domain: edge detector produces output pulse
//
// Constraints:
//   - Input pulses must be spaced at least 2 destination clock cycles apart
//   - If source is faster than destination, pulses may be lost
// =============================================================================

module pulse_synchronizer (
    // Source clock domain
    input  wire src_clk,
    input  wire src_rst_n,
    input  wire pulse_in,       // Single-cycle pulse in source domain

    // Destination clock domain
    input  wire dst_clk,
    input  wire dst_rst_n,
    output wire pulse_out       // Single-cycle pulse in destination domain
);

    // =========================================================================
    // Stage 1: Toggle register in source domain
    // =========================================================================
    // Each input pulse toggles this flip-flop, converting the pulse to a
    // level change that can be safely synchronized.
    reg toggle_src;

    always @(posedge src_clk or negedge src_rst_n) begin
        if (!src_rst_n)
            toggle_src <= 1'b0;
        else if (pulse_in)
            toggle_src <= ~toggle_src;
    end

    // =========================================================================
    // Stage 2: Two-flop synchronizer in destination domain
    // =========================================================================
    reg sync_ff1, sync_ff2, sync_ff3;

    always @(posedge dst_clk or negedge dst_rst_n) begin
        if (!dst_rst_n) begin
            sync_ff1 <= 1'b0;
            sync_ff2 <= 1'b0;
            sync_ff3 <= 1'b0;
        end else begin
            sync_ff1 <= toggle_src;    // First sync stage
            sync_ff2 <= sync_ff1;      // Second sync stage (metastability resolved)
            sync_ff3 <= sync_ff2;      // Third stage for edge detection
        end
    end

    // =========================================================================
    // Stage 3: Edge detector in destination domain
    // =========================================================================
    // XOR of consecutive samples detects both rising and falling edges
    // of the toggled signal, producing one pulse per source pulse.
    assign pulse_out = sync_ff2 ^ sync_ff3;

endmodule

// =============================================================================
// Pulse Synchronizer with Busy Feedback
// =============================================================================
// Enhanced version that provides a 'busy' signal to the source domain,
// preventing new pulses from being sent before the previous one completes.
// This guarantees no pulse loss.
// =============================================================================

module pulse_synchronizer_safe (
    // Source clock domain
    input  wire src_clk,
    input  wire src_rst_n,
    input  wire pulse_in,
    output wire busy,           // High when synchronizer is in use

    // Destination clock domain
    input  wire dst_clk,
    input  wire dst_rst_n,
    output wire pulse_out
);

    // Toggle in source domain
    reg toggle_src;
    reg pulse_accepted;

    always @(posedge src_clk or negedge src_rst_n) begin
        if (!src_rst_n) begin
            toggle_src     <= 1'b0;
            pulse_accepted <= 1'b0;
        end else begin
            pulse_accepted <= 1'b0;
            if (pulse_in && !busy) begin
                toggle_src     <= ~toggle_src;
                pulse_accepted <= 1'b1;
            end
        end
    end

    // Synchronize toggle to destination domain
    reg sync_ff1, sync_ff2, sync_ff3;

    always @(posedge dst_clk or negedge dst_rst_n) begin
        if (!dst_rst_n) begin
            sync_ff1 <= 1'b0;
            sync_ff2 <= 1'b0;
            sync_ff3 <= 1'b0;
        end else begin
            sync_ff1 <= toggle_src;
            sync_ff2 <= sync_ff1;
            sync_ff3 <= sync_ff2;
        end
    end

    assign pulse_out = sync_ff2 ^ sync_ff3;

    // Synchronize acknowledgment back to source domain
    reg ack_sync1, ack_sync2;

    always @(posedge src_clk or negedge src_rst_n) begin
        if (!src_rst_n) begin
            ack_sync1 <= 1'b0;
            ack_sync2 <= 1'b0;
        end else begin
            ack_sync1 <= sync_ff2;
            ack_sync2 <= ack_sync1;
        end
    end

    // Busy when toggle_src differs from acknowledged value
    assign busy = (toggle_src != ack_sync2);

endmodule
