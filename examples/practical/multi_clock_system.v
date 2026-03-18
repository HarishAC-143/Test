// =============================================================================
// Practical Example: Multi-Clock System with Various CDC Techniques
// =============================================================================
// A realistic system-level example integrating multiple CDC synchronization
// techniques. This represents a common SoC subsystem pattern:
//
//   - Core runs at clk_core (fast)
//   - Peripheral bus runs at clk_peri (slow)
//   - External I/O runs at clk_io (unrelated)
//
// CDC techniques demonstrated:
//   1. 2-FF synchronizer (single-bit control signals)
//   2. Gray-coded FIFO pointers (streaming data)
//   3. Handshake protocol (register access across domains)
//   4. Pulse synchronizer (edge events)
//   5. Reset synchronizer (reset distribution)
//
// This module should pass SpyGlass CDC with zero violations when
// proper constraints are applied (see constraints/cdc_constraints.sgdc).
// =============================================================================

module multi_clock_system (
    // Clocks and resets
    input  wire        clk_core,      // 200 MHz core clock
    input  wire        clk_peri,      // 50 MHz peripheral clock
    input  wire        clk_io,        // 33 MHz I/O clock
    input  wire        master_rst_n,  // Async master reset

    // Core domain I/O
    input  wire [31:0] core_data_in,
    input  wire        core_wr_en,
    output wire        core_fifo_full,

    // Peripheral domain I/O
    output wire [31:0] peri_data_out,
    output wire        peri_data_valid,
    input  wire        peri_rd_en,
    output wire        peri_fifo_empty,

    // I/O domain
    input  wire        io_interrupt,   // Async interrupt from external device
    output reg         io_ack,

    // Cross-domain status
    output wire        system_ready
);

    // =========================================================================
    // Reset Synchronization — Each domain gets its own synchronized reset
    // =========================================================================
    wire rst_core_n, rst_peri_n, rst_io_n;

    reset_synchronizer #(.SYNC_STAGES(2)) u_rst_core (
        .clk        (clk_core),
        .rst_async_n(master_rst_n),
        .rst_sync_n (rst_core_n)
    );

    reset_synchronizer #(.SYNC_STAGES(2)) u_rst_peri (
        .clk        (clk_peri),
        .rst_async_n(master_rst_n),
        .rst_sync_n (rst_peri_n)
    );

    reset_synchronizer #(.SYNC_STAGES(2)) u_rst_io (
        .clk        (clk_io),
        .rst_async_n(master_rst_n),
        .rst_sync_n (rst_io_n)
    );

    // =========================================================================
    // Technique 1: Async FIFO (Core → Peripheral data transfer)
    // =========================================================================
    // Streaming data from fast core domain to slow peripheral domain.
    // The async FIFO handles rate mismatch and clock domain crossing.

    async_fifo #(
        .DATA_WIDTH(32),
        .ADDR_WIDTH(3)       // 8-entry deep
    ) u_data_fifo (
        .wr_clk  (clk_core),
        .wr_rst_n(rst_core_n),
        .wr_en   (core_wr_en),
        .wr_data (core_data_in),
        .full    (core_fifo_full),
        .rd_clk  (clk_peri),
        .rd_rst_n(rst_peri_n),
        .rd_en   (peri_rd_en),
        .rd_data (peri_data_out),
        .empty   (peri_fifo_empty)
    );

    assign peri_data_valid = ~peri_fifo_empty;

    // =========================================================================
    // Technique 2: Pulse Synchronizer (I/O interrupt → Core)
    // =========================================================================
    // External interrupt arrives in clk_io domain. We need to deliver
    // a single-cycle pulse in clk_core domain.
    //
    // Pattern: Toggle in source domain, detect edge in destination domain.

    reg  io_int_toggle;
    reg  int_sync1, int_sync2, int_sync3;
    wire core_interrupt;

    // Toggle on each interrupt edge in I/O domain
    always @(posedge clk_io or negedge rst_io_n) begin
        if (!rst_io_n)
            io_int_toggle <= 1'b0;
        else if (io_interrupt)
            io_int_toggle <= ~io_int_toggle;
    end

    // 2-FF synchronizer + edge detector in core domain
    always @(posedge clk_core or negedge rst_core_n) begin
        if (!rst_core_n) begin
            int_sync1 <= 1'b0;
            int_sync2 <= 1'b0;
            int_sync3 <= 1'b0;
        end else begin
            int_sync1 <= io_int_toggle;     // sync stage 1
            int_sync2 <= int_sync1;         // sync stage 2
            int_sync3 <= int_sync2;         // delayed copy for edge detection
        end
    end

    // XOR of sync2 and sync3 produces a pulse when toggle changes
    assign core_interrupt = int_sync2 ^ int_sync3;

    // =========================================================================
    // Technique 3: Handshake (Core → I/O acknowledgment)
    // =========================================================================
    // Send acknowledgment from core domain to I/O domain using
    // a simple toggle handshake.

    reg core_ack_toggle;
    reg ack_sync1_io, ack_sync2_io, ack_prev_io;

    // Core domain: toggle ack on each interrupt received
    always @(posedge clk_core or negedge rst_core_n) begin
        if (!rst_core_n)
            core_ack_toggle <= 1'b0;
        else if (core_interrupt)
            core_ack_toggle <= ~core_ack_toggle;
    end

    // Synchronize ack toggle into I/O domain
    always @(posedge clk_io or negedge rst_io_n) begin
        if (!rst_io_n) begin
            ack_sync1_io <= 1'b0;
            ack_sync2_io <= 1'b0;
            ack_prev_io  <= 1'b0;
        end else begin
            ack_sync1_io <= core_ack_toggle;
            ack_sync2_io <= ack_sync1_io;
            ack_prev_io  <= ack_sync2_io;
        end
    end

    always @(posedge clk_io or negedge rst_io_n) begin
        if (!rst_io_n)
            io_ack <= 1'b0;
        else
            io_ack <= (ack_sync2_io != ack_prev_io);
    end

    // =========================================================================
    // Technique 4: 2-FF Synchronizer for Status (Peripheral → Core)
    // =========================================================================
    // Single-bit status signal from peripheral domain to core.

    reg peri_ready;
    reg ready_sync1, ready_sync2;

    always @(posedge clk_peri or negedge rst_peri_n) begin
        if (!rst_peri_n)
            peri_ready <= 1'b0;
        else
            peri_ready <= 1'b1;    // Goes high after reset de-asserts
    end

    always @(posedge clk_core or negedge rst_core_n) begin
        if (!rst_core_n) begin
            ready_sync1 <= 1'b0;
            ready_sync2 <= 1'b0;
        end else begin
            ready_sync1 <= peri_ready;
            ready_sync2 <= ready_sync1;
        end
    end

    assign system_ready = ready_sync2;

endmodule
