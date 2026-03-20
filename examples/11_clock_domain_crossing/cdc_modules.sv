// Clock Domain Crossing (CDC) Modules
// Safely transferring signals between unrelated clock domains is one of the
// most critical aspects of multi-clock FPGA design. Incorrect CDC causes
// metastability, data corruption, and intermittent failures.

// ============================================================================
// 2-FF Synchronizer for single-bit signals
// The fundamental building block: two flip-flops in series allow the
// first FF to go metastable and settle before the second FF samples.
// ============================================================================
module sync_2ff (
    input  logic clk_dest,
    input  logic rst_n,
    input  logic async_in,
    output logic sync_out
);
    logic meta_ff;

    always_ff @(posedge clk_dest or negedge rst_n) begin
        if (!rst_n) begin
            meta_ff  <= 1'b0;
            sync_out <= 1'b0;
        end else begin
            meta_ff  <= async_in;
            sync_out <= meta_ff;
        end
    end
endmodule


// ============================================================================
// Pulse Synchronizer
// Transfers a single-cycle pulse from one domain to another.
// Uses toggle + 2FF synchronizer + edge detect.
// ============================================================================
module pulse_sync (
    // Source domain
    input  logic src_clk,
    input  logic src_rst_n,
    input  logic src_pulse,

    // Destination domain
    input  logic dst_clk,
    input  logic dst_rst_n,
    output logic dst_pulse
);
    // Toggle FF in source domain
    logic toggle_ff;
    always_ff @(posedge src_clk or negedge src_rst_n) begin
        if (!src_rst_n)
            toggle_ff <= 1'b0;
        else if (src_pulse)
            toggle_ff <= ~toggle_ff;
    end

    // Synchronize toggle into destination domain
    logic sync1, sync2, sync3;
    always_ff @(posedge dst_clk or negedge dst_rst_n) begin
        if (!dst_rst_n) begin
            sync1 <= 1'b0;
            sync2 <= 1'b0;
            sync3 <= 1'b0;
        end else begin
            sync1 <= toggle_ff;
            sync2 <= sync1;
            sync3 <= sync2;
        end
    end

    // Edge detect: pulse on any toggle transition
    assign dst_pulse = sync2 ^ sync3;
endmodule


// ============================================================================
// Multi-bit CDC using Gray Code
// For counters and pointers, Gray code ensures only one bit changes at a time.
// ============================================================================
module gray_code_sync #(
    parameter int WIDTH = 4
) (
    input  logic             src_clk,
    input  logic             src_rst_n,
    input  logic [WIDTH-1:0] src_binary,

    input  logic             dst_clk,
    input  logic             dst_rst_n,
    output logic [WIDTH-1:0] dst_binary
);
    // Convert to Gray in source domain
    logic [WIDTH-1:0] src_gray;
    assign src_gray = src_binary ^ (src_binary >> 1);

    // Synchronize Gray code to destination domain
    logic [WIDTH-1:0] gray_sync1, gray_sync2;
    always_ff @(posedge dst_clk or negedge dst_rst_n) begin
        if (!dst_rst_n) begin
            gray_sync1 <= '0;
            gray_sync2 <= '0;
        end else begin
            gray_sync1 <= src_gray;
            gray_sync2 <= gray_sync1;
        end
    end

    // Convert Gray back to binary in destination domain
    always_comb begin
        dst_binary[WIDTH-1] = gray_sync2[WIDTH-1];
        for (int i = WIDTH-2; i >= 0; i--)
            dst_binary[i] = dst_binary[i+1] ^ gray_sync2[i];
    end
endmodule


// ============================================================================
// Handshake Synchronizer for multi-bit data
// Uses req/ack handshake to safely transfer a data bus across clock domains.
// Slower than async FIFO but simpler; good for control/config registers.
// ============================================================================
module handshake_sync #(
    parameter int DATA_WIDTH = 32
) (
    // Source domain
    input  logic                  src_clk,
    input  logic                  src_rst_n,
    input  logic [DATA_WIDTH-1:0] src_data,
    input  logic                  src_valid,
    output logic                  src_ready,

    // Destination domain
    input  logic                  dst_clk,
    input  logic                  dst_rst_n,
    output logic [DATA_WIDTH-1:0] dst_data,
    output logic                  dst_valid
);

    logic                  req_src, ack_src;
    logic                  req_dst, ack_dst;
    logic [DATA_WIDTH-1:0] data_hold;

    // Source domain: latch data and assert request
    always_ff @(posedge src_clk or negedge src_rst_n) begin
        if (!src_rst_n) begin
            req_src   <= 1'b0;
            data_hold <= '0;
        end else begin
            if (src_valid && src_ready) begin
                data_hold <= src_data;
                req_src   <= 1'b1;
            end else if (ack_src) begin
                req_src <= 1'b0;
            end
        end
    end

    assign src_ready = !req_src;

    // Synchronize req into destination domain
    sync_2ff u_req_sync (
        .clk_dest  (dst_clk),
        .rst_n     (dst_rst_n),
        .async_in  (req_src),
        .sync_out  (req_dst)
    );

    // Destination domain: capture data and assert ack
    always_ff @(posedge dst_clk or negedge dst_rst_n) begin
        if (!dst_rst_n) begin
            ack_dst   <= 1'b0;
            dst_data  <= '0;
            dst_valid <= 1'b0;
        end else begin
            dst_valid <= 1'b0;
            if (req_dst && !ack_dst) begin
                dst_data  <= data_hold;
                dst_valid <= 1'b1;
                ack_dst   <= 1'b1;
            end else if (!req_dst) begin
                ack_dst <= 1'b0;
            end
        end
    end

    // Synchronize ack back into source domain
    sync_2ff u_ack_sync (
        .clk_dest  (src_clk),
        .rst_n     (src_rst_n),
        .async_in  (ack_dst),
        .sync_out  (ack_src)
    );

endmodule
