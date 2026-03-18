//-----------------------------------------------------------------------------
// Synchronizer Library: Handshake Synchronizer
//
// Use Case:
//   Transferring multi-bit data across clock domains when throughput
//   requirements are low. The handshake guarantees that the data bus
//   is stable before the receiver samples it.
//
// Protocol:
//   1. Source asserts req and holds data stable
//   2. Destination synchronizes req, captures data, asserts ack
//   3. Source synchronizes ack, deasserts req
//   4. Destination sees req deasserted, deasserts ack
//   → 4-phase handshake (req↑, ack↑, req↓, ack↓)
//
// Characteristics:
//   - Latency: ~4-6 cycles (round-trip synchronization)
//   - Throughput: 1 transfer per handshake cycle
//   - Data width: Arbitrary (data is held stable, not synchronized)
//   - Safety: Guaranteed — no metastability on data bus
//
// SpyGlass:
//   Will recognize the handshake pattern if req/ack are properly
//   synchronized. The data bus is flagged as CDC-safe because it
//   is qualified by the synchronized req signal.
//-----------------------------------------------------------------------------

module sync_handshake #(
    parameter DATA_WIDTH = 8
) (
    // Source side
    input  wire                   clk_src,
    input  wire                   rst_src_n,
    input  wire                   valid_in,      // Pulse: new data available
    input  wire [DATA_WIDTH-1:0]  data_in,
    output wire                   ready,         // High when ready for new data

    // Destination side
    input  wire                   clk_dst,
    input  wire                   rst_dst_n,
    output reg                    valid_out,     // Pulse: data captured
    output reg  [DATA_WIDTH-1:0]  data_out
);

    //=========================================================================
    // Source Domain
    //=========================================================================
    reg                   req_src;
    reg [DATA_WIDTH-1:0]  data_src;
    wire                  ack_synced;

    // Synchronize ack from destination → source
    reg ack_sync1, ack_sync2;
    always @(posedge clk_src or negedge rst_src_n) begin
        if (!rst_src_n) begin
            ack_sync1 <= 1'b0;
            ack_sync2 <= 1'b0;
        end else begin
            ack_sync1 <= ack_dst;
            ack_sync2 <= ack_sync1;
        end
    end
    assign ack_synced = ack_sync2;

    // Source FSM
    localparam S_IDLE = 1'b0, S_WAIT = 1'b1;
    reg src_state;

    assign ready = (src_state == S_IDLE);

    always @(posedge clk_src or negedge rst_src_n) begin
        if (!rst_src_n) begin
            src_state <= S_IDLE;
            req_src   <= 1'b0;
            data_src  <= {DATA_WIDTH{1'b0}};
        end else begin
            case (src_state)
                S_IDLE: begin
                    if (valid_in) begin
                        data_src  <= data_in;   // Capture data
                        req_src   <= 1'b1;      // Assert request
                        src_state <= S_WAIT;
                    end
                end
                S_WAIT: begin
                    if (ack_synced) begin
                        req_src   <= 1'b0;      // Deassert request
                        src_state <= S_IDLE;
                    end
                end
                default: src_state <= S_IDLE;
            endcase
        end
    end

    //=========================================================================
    // Destination Domain
    //=========================================================================
    reg ack_dst;
    wire req_synced;

    // Synchronize req from source → destination
    reg req_sync1, req_sync2;
    always @(posedge clk_dst or negedge rst_dst_n) begin
        if (!rst_dst_n) begin
            req_sync1 <= 1'b0;
            req_sync2 <= 1'b0;
        end else begin
            req_sync1 <= req_src;
            req_sync2 <= req_sync1;
        end
    end
    assign req_synced = req_sync2;

    // Destination FSM
    localparam D_IDLE = 1'b0, D_ACK = 1'b1;
    reg dst_state;

    always @(posedge clk_dst or negedge rst_dst_n) begin
        if (!rst_dst_n) begin
            dst_state <= D_IDLE;
            ack_dst   <= 1'b0;
            valid_out <= 1'b0;
            data_out  <= {DATA_WIDTH{1'b0}};
        end else begin
            valid_out <= 1'b0;  // Default: pulse
            case (dst_state)
                D_IDLE: begin
                    if (req_synced) begin
                        data_out  <= data_src;   // Safe: data is stable while req is high
                        valid_out <= 1'b1;        // Output pulse
                        ack_dst   <= 1'b1;        // Acknowledge
                        dst_state <= D_ACK;
                    end
                end
                D_ACK: begin
                    if (!req_synced) begin
                        ack_dst   <= 1'b0;        // Deassert ack
                        dst_state <= D_IDLE;
                    end
                end
                default: dst_state <= D_IDLE;
            endcase
        end
    end

endmodule
