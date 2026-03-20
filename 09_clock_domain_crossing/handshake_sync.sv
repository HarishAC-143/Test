// Handshake-based multi-bit synchronizer.
//
// Safely transfers a multi-bit data word from source to destination domain.
// Uses a req/ack handshake protocol:
// 1. Source asserts req with stable data
// 2. Destination captures data, asserts ack
// 3. Source sees ack, deasserts req
// 4. Destination sees req deasserted, deasserts ack
//
// Lower throughput than an async FIFO, but simpler and suitable for
// configuration registers or infrequent transfers.

module handshake_sync #(
    parameter int DATA_WIDTH = 32
)(
    // Source domain
    input  logic                  src_clk,
    input  logic                  src_rst_n,
    input  logic                  src_valid,   // pulse to initiate transfer
    input  logic [DATA_WIDTH-1:0] src_data,
    output logic                  src_busy,    // high while transfer in progress

    // Destination domain
    input  logic                  dst_clk,
    input  logic                  dst_rst_n,
    output logic                  dst_valid,   // pulse when data is available
    output logic [DATA_WIDTH-1:0] dst_data
);

    // Source domain signals
    logic req_src;
    logic ack_src_sync;
    logic [DATA_WIDTH-1:0] data_src_reg;

    // Destination domain signals
    logic req_dst_sync;
    logic ack_dst;
    logic req_dst_sync_d;

    // =========================================================================
    // Source domain: manage req and data
    // =========================================================================
    typedef enum logic [1:0] {
        SRC_IDLE,
        SRC_WAIT_ACK,
        SRC_WAIT_ACK_LOW
    } src_state_t;

    src_state_t src_state;

    always_ff @(posedge src_clk or negedge src_rst_n) begin
        if (!src_rst_n) begin
            src_state    <= SRC_IDLE;
            req_src      <= 1'b0;
            data_src_reg <= '0;
        end else begin
            unique case (src_state)
                SRC_IDLE: begin
                    if (src_valid) begin
                        data_src_reg <= src_data;
                        req_src      <= 1'b1;
                        src_state    <= SRC_WAIT_ACK;
                    end
                end

                SRC_WAIT_ACK: begin
                    if (ack_src_sync) begin
                        req_src   <= 1'b0;
                        src_state <= SRC_WAIT_ACK_LOW;
                    end
                end

                SRC_WAIT_ACK_LOW: begin
                    if (!ack_src_sync)
                        src_state <= SRC_IDLE;
                end

                default: src_state <= SRC_IDLE;
            endcase
        end
    end

    assign src_busy = (src_state != SRC_IDLE);

    // =========================================================================
    // Destination domain: capture data and manage ack
    // =========================================================================
    always_ff @(posedge dst_clk or negedge dst_rst_n) begin
        if (!dst_rst_n) begin
            ack_dst        <= 1'b0;
            dst_data       <= '0;
            req_dst_sync_d <= 1'b0;
        end else begin
            req_dst_sync_d <= req_dst_sync;

            if (req_dst_sync && !req_dst_sync_d) begin
                dst_data <= data_src_reg;
                ack_dst  <= 1'b1;
            end else if (!req_dst_sync) begin
                ack_dst <= 1'b0;
            end
        end
    end

    assign dst_valid = req_dst_sync && !req_dst_sync_d;

    // =========================================================================
    // Synchronizers
    // =========================================================================
    two_ff_sync u_req_sync (
        .clk_dst   (dst_clk),
        .rst_dst_n (dst_rst_n),
        .data_in   (req_src),
        .data_out  (req_dst_sync)
    );

    two_ff_sync u_ack_sync (
        .clk_dst   (src_clk),
        .rst_dst_n (src_rst_n),
        .data_in   (ack_dst),
        .data_out  (ack_src_sync)
    );

endmodule
