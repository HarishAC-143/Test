// =============================================================================
// Clock Domain Crossing (CDC) Primitives
// A collection of essential CDC synchronization circuits.
// =============================================================================

// =============================================================================
// 1. Two-Flop Synchronizer (for single-bit signals)
// =============================================================================
module sync_2ff #(
    parameter RESET_VALUE = 1'b0
) (
    input  logic clk_dest,
    input  logic rst_n,
    input  logic async_in,
    output logic sync_out
);

    logic meta_ff;

    always_ff @(posedge clk_dest or negedge rst_n) begin
        if (!rst_n) begin
            meta_ff  <= RESET_VALUE;
            sync_out <= RESET_VALUE;
        end else begin
            meta_ff  <= async_in;
            sync_out <= meta_ff;
        end
    end

endmodule

// =============================================================================
// 2. Pulse Synchronizer (transfers a single-cycle pulse across domains)
// =============================================================================
module pulse_synchronizer (
    // Source domain
    input  logic clk_src,
    input  logic rst_src_n,
    input  logic pulse_in,

    // Destination domain
    input  logic clk_dest,
    input  logic rst_dest_n,
    output logic pulse_out
);

    logic toggle_src;
    logic toggle_dest_meta, toggle_dest_sync, toggle_dest_prev;

    // Toggle in source domain on every pulse
    always_ff @(posedge clk_src or negedge rst_src_n) begin
        if (!rst_src_n)
            toggle_src <= 1'b0;
        else if (pulse_in)
            toggle_src <= ~toggle_src;
    end

    // Synchronize the toggle signal to the destination domain
    always_ff @(posedge clk_dest or negedge rst_dest_n) begin
        if (!rst_dest_n) begin
            toggle_dest_meta <= 1'b0;
            toggle_dest_sync <= 1'b0;
            toggle_dest_prev <= 1'b0;
        end else begin
            toggle_dest_meta <= toggle_src;
            toggle_dest_sync <= toggle_dest_meta;
            toggle_dest_prev <= toggle_dest_sync;
        end
    end

    // Detect edges of the synchronized toggle
    assign pulse_out = toggle_dest_sync ^ toggle_dest_prev;

endmodule

// =============================================================================
// 3. Handshake Synchronizer (multi-bit data transfer across domains)
// =============================================================================
module handshake_sync #(
    parameter DATA_WIDTH = 8
) (
    // Source domain
    input  logic                    clk_src,
    input  logic                    rst_src_n,
    input  logic                    src_valid,
    input  logic [DATA_WIDTH-1:0]   src_data,
    output logic                    src_ready,

    // Destination domain
    input  logic                    clk_dest,
    input  logic                    rst_dest_n,
    output logic                    dest_valid,
    output logic [DATA_WIDTH-1:0]   dest_data,
    input  logic                    dest_ready
);

    // Req/Ack signals
    logic req_src, ack_src;
    logic req_dest_meta, req_dest_sync;
    logic ack_dest, ack_src_meta, ack_src_sync;

    // Data holding register
    logic [DATA_WIDTH-1:0] data_hold;

    // Source domain: capture data and assert request
    always_ff @(posedge clk_src or negedge rst_src_n) begin
        if (!rst_src_n) begin
            req_src   <= 1'b0;
            data_hold <= '0;
        end else begin
            if (src_valid && src_ready && !req_src) begin
                data_hold <= src_data;
                req_src   <= 1'b1;
            end else if (ack_src_sync) begin
                req_src <= 1'b0;
            end
        end
    end

    assign src_ready = !req_src;

    // Synchronize ack back to source domain
    always_ff @(posedge clk_src or negedge rst_src_n) begin
        if (!rst_src_n) begin
            ack_src_meta <= 1'b0;
            ack_src_sync <= 1'b0;
        end else begin
            ack_src_meta <= ack_dest;
            ack_src_sync <= ack_src_meta;
        end
    end

    // Synchronize req to destination domain
    always_ff @(posedge clk_dest or negedge rst_dest_n) begin
        if (!rst_dest_n) begin
            req_dest_meta <= 1'b0;
            req_dest_sync <= 1'b0;
        end else begin
            req_dest_meta <= req_src;
            req_dest_sync <= req_dest_meta;
        end
    end

    // Destination domain: acknowledge when data consumed
    always_ff @(posedge clk_dest or negedge rst_dest_n) begin
        if (!rst_dest_n) begin
            ack_dest <= 1'b0;
        end else begin
            if (req_dest_sync && dest_ready)
                ack_dest <= 1'b1;
            else if (!req_dest_sync)
                ack_dest <= 1'b0;
        end
    end

    assign dest_valid = req_dest_sync && !ack_dest;
    assign dest_data  = data_hold;

endmodule
