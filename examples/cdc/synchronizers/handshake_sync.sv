// =============================================================================
// handshake_sync -- Four-Phase Handshake Synchronizer
//
// Transfers a multi-bit data payload between two asynchronous clock domains
// using a four-phase handshake protocol:
//
//   Phase 1: Source asserts REQ with data on the bus.
//   Phase 2: Destination sees REQ (after sync), captures data, asserts ACK.
//   Phase 3: Source sees ACK (after sync), deasserts REQ.
//   Phase 4: Destination sees REQ low, deasserts ACK. Handshake complete.
//
// Throughput: One transfer every ~4*(Tsync) cycles, where Tsync is
//             2 destination-clock cycles. Suitable for infrequent transfers.
//
// Parameters:
//   WIDTH -- data bus width (default 8)
// =============================================================================

module handshake_sync #(
    parameter WIDTH = 8
) (
    // Source domain
    input  wire             clk_src,
    input  wire             rst_src_n,
    input  wire [WIDTH-1:0] src_data,
    input  wire             src_valid,   // pulse: start a transfer
    output wire             src_ready,   // high when idle (ready for next)

    // Destination domain
    input  wire             clk_dst,
    input  wire             rst_dst_n,
    output reg  [WIDTH-1:0] dst_data,
    output reg              dst_valid    // pulse: data captured
);

    // -----------------------------------------------------------------
    // Source domain: REQ generation
    // -----------------------------------------------------------------
    reg             req_src;
    reg [WIDTH-1:0] data_hold;

    wire ack_src;     // ACK synchronized into source domain

    assign src_ready = ~req_src;

    always @(posedge clk_src or negedge rst_src_n) begin
        if (!rst_src_n) begin
            req_src   <= 1'b0;
            data_hold <= {WIDTH{1'b0}};
        end else begin
            if (src_valid && src_ready) begin
                req_src   <= 1'b1;
                data_hold <= src_data;
            end else if (ack_src) begin
                req_src <= 1'b0;       // Phase 3: deassert REQ
            end
        end
    end

    // -----------------------------------------------------------------
    // Synchronize REQ into destination domain
    // -----------------------------------------------------------------
    wire req_dst;

    sync_2ff #(.WIDTH(1)) u_sync_req (
        .clk   (clk_dst),
        .rst_n (rst_dst_n),
        .d     (req_src),
        .q     (req_dst)
    );

    // -----------------------------------------------------------------
    // Destination domain: capture data, generate ACK
    // -----------------------------------------------------------------
    reg ack_dst;
    reg req_dst_d;

    always @(posedge clk_dst or negedge rst_dst_n) begin
        if (!rst_dst_n) begin
            ack_dst   <= 1'b0;
            dst_data  <= {WIDTH{1'b0}};
            dst_valid <= 1'b0;
            req_dst_d <= 1'b0;
        end else begin
            req_dst_d <= req_dst;
            dst_valid <= 1'b0;

            if (req_dst && !req_dst_d) begin
                dst_data  <= data_hold;   // capture on rising edge of req
                dst_valid <= 1'b1;
                ack_dst   <= 1'b1;        // Phase 2: assert ACK
            end else if (!req_dst && req_dst_d) begin
                ack_dst <= 1'b0;          // Phase 4: deassert ACK
            end
        end
    end

    // -----------------------------------------------------------------
    // Synchronize ACK back into source domain
    // -----------------------------------------------------------------
    sync_2ff #(.WIDTH(1)) u_sync_ack (
        .clk   (clk_dst),
        .rst_n (rst_src_n),
        .d     (ack_dst),
        .q     (ack_src)
    );

endmodule
