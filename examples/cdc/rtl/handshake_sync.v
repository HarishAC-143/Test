// =============================================================================
// Handshake Synchronizer
// =============================================================================
// Transfers multi-bit data between clock domains using a request/acknowledge
// handshake protocol. Guarantees data coherency for bus transfers.
//
// Protocol:
//   1. Source asserts req after placing stable data on data_in
//   2. req is synchronized to destination domain
//   3. Destination captures data_in (stable due to handshake)
//   4. Destination asserts ack
//   5. ack is synchronized back to source domain
//   6. Source deasserts req
//   7. Destination sees req deasserted, deasserts ack
//   8. Source sees ack deasserted — ready for next transfer
//
// Throughput: ~4-6 destination clock cycles per transfer
// Use for: Infrequent multi-bit transfers (config registers, status words)
// Do NOT use for: High-bandwidth streaming (use async FIFO instead)
// =============================================================================

module handshake_sync #(
    parameter DATA_WIDTH = 32
) (
    // Source clock domain
    input  wire                    src_clk,
    input  wire                    src_rst_n,
    input  wire [DATA_WIDTH-1:0]   src_data,
    input  wire                    src_valid,    // Pulse to start transfer
    output wire                    src_ready,    // High when ready for new data

    // Destination clock domain
    input  wire                    dst_clk,
    input  wire                    dst_rst_n,
    output reg  [DATA_WIDTH-1:0]   dst_data,
    output wire                    dst_valid     // Pulse when new data available
);

    // =========================================================================
    // Source Domain: Request Generation
    // =========================================================================
    reg                    req_src;
    reg [DATA_WIDTH-1:0]   data_held;

    // Synchronize ack from destination back to source
    reg ack_src_sync1, ack_src_sync2;

    always @(posedge src_clk or negedge src_rst_n) begin
        if (!src_rst_n) begin
            ack_src_sync1 <= 1'b0;
            ack_src_sync2 <= 1'b0;
        end else begin
            ack_src_sync1 <= ack_dst;
            ack_src_sync2 <= ack_src_sync1;
        end
    end

    // Source state machine
    localparam SRC_IDLE = 1'b0,
               SRC_WAIT = 1'b1;

    reg src_state;

    always @(posedge src_clk or negedge src_rst_n) begin
        if (!src_rst_n) begin
            src_state <= SRC_IDLE;
            req_src   <= 1'b0;
            data_held <= {DATA_WIDTH{1'b0}};
        end else begin
            case (src_state)
                SRC_IDLE: begin
                    if (src_valid) begin
                        data_held <= src_data;
                        req_src   <= 1'b1;
                        src_state <= SRC_WAIT;
                    end
                end

                SRC_WAIT: begin
                    if (ack_src_sync2) begin
                        req_src   <= 1'b0;
                        src_state <= SRC_IDLE;
                    end
                end

                default: begin
                    src_state <= SRC_IDLE;
                    req_src   <= 1'b0;
                end
            endcase
        end
    end

    assign src_ready = (src_state == SRC_IDLE);

    // =========================================================================
    // Destination Domain: Request Synchronization and Data Capture
    // =========================================================================

    // Synchronize request from source to destination
    reg req_dst_sync1, req_dst_sync2;

    always @(posedge dst_clk or negedge dst_rst_n) begin
        if (!dst_rst_n) begin
            req_dst_sync1 <= 1'b0;
            req_dst_sync2 <= 1'b0;
        end else begin
            req_dst_sync1 <= req_src;
            req_dst_sync2 <= req_dst_sync1;
        end
    end

    // Destination state machine
    localparam DST_IDLE    = 2'd0,
               DST_CAPTURE = 2'd1,
               DST_ACK     = 2'd2;

    reg [1:0] dst_state;
    reg       ack_dst;
    reg       dst_valid_reg;

    always @(posedge dst_clk or negedge dst_rst_n) begin
        if (!dst_rst_n) begin
            dst_state     <= DST_IDLE;
            ack_dst       <= 1'b0;
            dst_data      <= {DATA_WIDTH{1'b0}};
            dst_valid_reg <= 1'b0;
        end else begin
            dst_valid_reg <= 1'b0;

            case (dst_state)
                DST_IDLE: begin
                    if (req_dst_sync2) begin
                        dst_data      <= data_held;  // Safe: data is held stable
                        dst_valid_reg <= 1'b1;
                        dst_state     <= DST_ACK;
                    end
                end

                DST_ACK: begin
                    ack_dst   <= 1'b1;
                    if (!req_dst_sync2) begin
                        ack_dst   <= 1'b0;
                        dst_state <= DST_IDLE;
                    end
                end

                default: begin
                    dst_state <= DST_IDLE;
                    ack_dst   <= 1'b0;
                end
            endcase
        end
    end

    assign dst_valid = dst_valid_reg;

endmodule
