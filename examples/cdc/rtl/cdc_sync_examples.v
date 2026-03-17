// =============================================================================
// CDC Synchronizer Building Blocks
// =============================================================================
// A collection of reusable CDC synchronizer primitives.
// These are the fundamental building blocks for safe clock domain crossings.
// =============================================================================

// -----------------------------------------------------------------------------
// 1. Two-Flop Synchronizer (Single-Bit)
// -----------------------------------------------------------------------------
// The most basic synchronizer for single-bit control signals.
// Reduces metastability probability to negligible levels (MTBF > design life).
// -----------------------------------------------------------------------------
module sync_2ff #(
    parameter INIT_VAL = 1'b0
) (
    input  wire clk_dst,      // Destination clock
    input  wire rst_dst_n,    // Destination async reset (active low)
    input  wire data_in,      // Asynchronous input from source domain
    output wire data_out      // Synchronized output in destination domain
);

    reg sync_stage1, sync_stage2;

    always @(posedge clk_dst or negedge rst_dst_n) begin
        if (!rst_dst_n) begin
            sync_stage1 <= INIT_VAL;
            sync_stage2 <= INIT_VAL;
        end else begin
            sync_stage1 <= data_in;
            sync_stage2 <= sync_stage1;
        end
    end

    assign data_out = sync_stage2;

endmodule

// -----------------------------------------------------------------------------
// 2. Three-Flop Synchronizer (Higher MTBF)
// -----------------------------------------------------------------------------
// Used when two flops provide insufficient MTBF at the target frequency.
// Common in high-speed designs (> 500 MHz) or safety-critical applications.
// -----------------------------------------------------------------------------
module sync_3ff #(
    parameter INIT_VAL = 1'b0
) (
    input  wire clk_dst,
    input  wire rst_dst_n,
    input  wire data_in,
    output wire data_out
);

    reg sync_stage1, sync_stage2, sync_stage3;

    always @(posedge clk_dst or negedge rst_dst_n) begin
        if (!rst_dst_n) begin
            sync_stage1 <= INIT_VAL;
            sync_stage2 <= INIT_VAL;
            sync_stage3 <= INIT_VAL;
        end else begin
            sync_stage1 <= data_in;
            sync_stage2 <= sync_stage1;
            sync_stage3 <= sync_stage2;
        end
    end

    assign data_out = sync_stage3;

endmodule

// -----------------------------------------------------------------------------
// 3. Bus Synchronizer (Multi-Bit with Qualifier)
// -----------------------------------------------------------------------------
// Safely transfers a multi-bit bus using a single synchronizer on the
// valid/enable signal. The bus must be stable whenever valid is asserted.
// -----------------------------------------------------------------------------
module sync_bus #(
    parameter WIDTH = 8
) (
    input  wire             clk_dst,
    input  wire             rst_dst_n,
    input  wire [WIDTH-1:0] data_in,      // Must be stable when valid_in is high
    input  wire             valid_in,      // Asserted when data_in is stable
    output reg  [WIDTH-1:0] data_out,
    output wire             valid_out
);

    wire valid_synced;

    sync_2ff u_valid_sync (
        .clk_dst   (clk_dst),
        .rst_dst_n (rst_dst_n),
        .data_in   (valid_in),
        .data_out  (valid_synced)
    );

    reg valid_synced_d;

    always @(posedge clk_dst or negedge rst_dst_n) begin
        if (!rst_dst_n)
            valid_synced_d <= 1'b0;
        else
            valid_synced_d <= valid_synced;
    end

    assign valid_out = valid_synced & ~valid_synced_d;  // Rising edge detect

    always @(posedge clk_dst or negedge rst_dst_n) begin
        if (!rst_dst_n)
            data_out <= {WIDTH{1'b0}};
        else if (valid_out)
            data_out <= data_in;
    end

endmodule

// -----------------------------------------------------------------------------
// 4. Reset Synchronizer
// -----------------------------------------------------------------------------
// Synchronizes an asynchronous reset deassertion to the destination clock.
// Reset assertion is asynchronous (immediate), deassertion is synchronous.
// -----------------------------------------------------------------------------
module sync_reset (
    input  wire clk_dst,
    input  wire rst_async_n,    // Asynchronous reset (active low)
    output wire rst_sync_n      // Synchronized reset (active low)
);

    reg sync_stage1, sync_stage2;

    always @(posedge clk_dst or negedge rst_async_n) begin
        if (!rst_async_n) begin
            sync_stage1 <= 1'b0;
            sync_stage2 <= 1'b0;
        end else begin
            sync_stage1 <= 1'b1;
            sync_stage2 <= sync_stage1;
        end
    end

    assign rst_sync_n = sync_stage2;

endmodule

// -----------------------------------------------------------------------------
// 5. Level-to-Pulse Synchronizer
// -----------------------------------------------------------------------------
// Converts a level signal from the source domain into a single-cycle pulse
// in the destination domain. Useful for event signaling.
// -----------------------------------------------------------------------------
module sync_level_to_pulse (
    input  wire clk_dst,
    input  wire rst_dst_n,
    input  wire level_in,      // Level signal from source domain
    output wire pulse_out      // Single-cycle pulse in destination domain
);

    wire level_synced;

    sync_2ff u_sync (
        .clk_dst   (clk_dst),
        .rst_dst_n (rst_dst_n),
        .data_in   (level_in),
        .data_out  (level_synced)
    );

    reg level_synced_d;

    always @(posedge clk_dst or negedge rst_dst_n) begin
        if (!rst_dst_n)
            level_synced_d <= 1'b0;
        else
            level_synced_d <= level_synced;
    end

    assign pulse_out = level_synced & ~level_synced_d;

endmodule
