// ----------------------------------------------------------------------------
// Clock Domain Crossing (CDC) Primitives Library
// Demonstrates: 2-FF synchronizer, pulse synchronizer, handshake synchronizer,
//               bus synchronizer with MUX recirculation
// ----------------------------------------------------------------------------

// ===== 1. Two-Flop Synchronizer (Single Bit) =====
// Use for slow-changing single-bit signals crossing clock domains
module cdc_sync_2ff #(
    parameter int NUM_STAGES = 2,   // Minimum 2 for MTBF
    parameter bit RESET_VAL  = 0
)(
    input  logic clk_dest,
    input  logic rst_dest_n,
    input  logic signal_src,
    output logic signal_dest
);

    (* async_reg = "true" *)
    logic [NUM_STAGES-1:0] sync_chain;

    always_ff @(posedge clk_dest or negedge rst_dest_n) begin
        if (!rst_dest_n)
            sync_chain <= {NUM_STAGES{RESET_VAL}};
        else
            sync_chain <= {sync_chain[NUM_STAGES-2:0], signal_src};
    end

    assign signal_dest = sync_chain[NUM_STAGES-1];

endmodule


// ===== 2. Pulse Synchronizer =====
// Transfers a single-cycle pulse from source to destination domain
module cdc_pulse_sync (
    // Source domain
    input  logic clk_src,
    input  logic rst_src_n,
    input  logic pulse_src,

    // Destination domain
    input  logic clk_dest,
    input  logic rst_dest_n,
    output logic pulse_dest
);

    logic toggle_src;
    logic toggle_dest, toggle_dest_prev;

    // Toggle a register on each pulse in source domain
    always_ff @(posedge clk_src or negedge rst_src_n) begin
        if (!rst_src_n)
            toggle_src <= 1'b0;
        else if (pulse_src)
            toggle_src <= ~toggle_src;
    end

    // Synchronize the toggle signal to destination domain
    cdc_sync_2ff #(.NUM_STAGES(2)) u_sync (
        .clk_dest    (clk_dest),
        .rst_dest_n  (rst_dest_n),
        .signal_src  (toggle_src),
        .signal_dest (toggle_dest)
    );

    // Detect edges on the synchronized toggle to reconstruct the pulse
    always_ff @(posedge clk_dest or negedge rst_dest_n) begin
        if (!rst_dest_n)
            toggle_dest_prev <= 1'b0;
        else
            toggle_dest_prev <= toggle_dest;
    end

    assign pulse_dest = toggle_dest ^ toggle_dest_prev;

endmodule


// ===== 3. Handshake Synchronizer =====
// Safe multi-bit data transfer between clock domains using req/ack handshake
module cdc_handshake #(
    parameter int DATA_WIDTH = 32
)(
    // Source domain
    input  logic                    clk_src,
    input  logic                    rst_src_n,
    input  logic [DATA_WIDTH-1:0]   data_src,
    input  logic                    valid_src,
    output logic                    ready_src,

    // Destination domain
    input  logic                    clk_dest,
    input  logic                    rst_dest_n,
    output logic [DATA_WIDTH-1:0]   data_dest,
    output logic                    valid_dest
);

    logic                    req_src;
    logic                    req_dest;
    logic                    ack_src;
    logic                    ack_dest;
    logic [DATA_WIDTH-1:0]   data_hold;

    // Source: capture data and assert request
    always_ff @(posedge clk_src or negedge rst_src_n) begin
        if (!rst_src_n) begin
            req_src   <= 1'b0;
            data_hold <= '0;
        end else begin
            if (valid_src && ready_src) begin
                data_hold <= data_src;
                req_src   <= 1'b1;
            end else if (ack_src) begin
                req_src <= 1'b0;
            end
        end
    end

    assign ready_src = !req_src;

    // Synchronize req to destination domain
    cdc_sync_2ff u_req_sync (
        .clk_dest    (clk_dest),
        .rst_dest_n  (rst_dest_n),
        .signal_src  (req_src),
        .signal_dest (req_dest)
    );

    // Destination: capture data when req arrives
    always_ff @(posedge clk_dest or negedge rst_dest_n) begin
        if (!rst_dest_n) begin
            data_dest  <= '0;
            valid_dest <= 1'b0;
            ack_dest   <= 1'b0;
        end else begin
            valid_dest <= 1'b0;
            if (req_dest && !ack_dest) begin
                data_dest  <= data_hold;    // Data is stable while req is high
                valid_dest <= 1'b1;
                ack_dest   <= 1'b1;
            end else if (!req_dest) begin
                ack_dest <= 1'b0;
            end
        end
    end

    // Synchronize ack back to source domain
    cdc_sync_2ff u_ack_sync (
        .clk_dest    (clk_src),
        .rst_dest_n  (rst_src_n),
        .signal_src  (ack_dest),
        .signal_dest (ack_src)
    );

endmodule


// ===== 4. Bus Synchronizer (MUX Recirculation) =====
// Uses a load-enable synchronized signal to safely transfer a multi-bit bus
module cdc_bus_sync #(
    parameter int DATA_WIDTH = 8
)(
    input  logic                    clk_src,
    input  logic                    rst_src_n,
    input  logic [DATA_WIDTH-1:0]   data_src,
    input  logic                    load_src,    // Pulse when data_src is valid

    input  logic                    clk_dest,
    input  logic                    rst_dest_n,
    output logic [DATA_WIDTH-1:0]   data_dest,
    output logic                    valid_dest
);

    logic [DATA_WIDTH-1:0] data_hold;
    logic                  load_dest;

    // Hold data stable in source domain
    always_ff @(posedge clk_src or negedge rst_src_n) begin
        if (!rst_src_n)
            data_hold <= '0;
        else if (load_src)
            data_hold <= data_src;
    end

    // Synchronize the load pulse
    cdc_pulse_sync u_load_sync (
        .clk_src    (clk_src),
        .rst_src_n  (rst_src_n),
        .pulse_src  (load_src),
        .clk_dest   (clk_dest),
        .rst_dest_n (rst_dest_n),
        .pulse_dest (load_dest)
    );

    // Capture in destination domain when load arrives
    always_ff @(posedge clk_dest or negedge rst_dest_n) begin
        if (!rst_dest_n) begin
            data_dest  <= '0;
            valid_dest <= 1'b0;
        end else begin
            valid_dest <= load_dest;
            if (load_dest)
                data_dest <= data_hold;
        end
    end

endmodule
