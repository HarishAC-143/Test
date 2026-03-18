//-----------------------------------------------------------------------------
// Example: Reusable 2-FF Synchronizer Module
//
// This is the fundamental CDC building block. It synchronizes a single-bit
// signal from one clock domain to another.
//
// Design constraints:
//   - Both flip-flops should be placed close together (synthesis attribute)
//   - No combinational logic between the two stages
//   - Only for single-bit signals; multi-bit requires different techniques
//
// SpyGlass will recognize this pattern as a valid synchronizer when
// properly constrained.
//-----------------------------------------------------------------------------

module sync_2ff #(
    parameter RESET_VAL = 1'b0,   // Reset value for sync registers
    parameter NUM_STAGES = 2      // Number of synchronizer stages (min 2)
) (
    input  wire clk_dst,     // Destination domain clock
    input  wire rst_dst_n,   // Destination domain async reset (active low)
    input  wire data_in,     // Asynchronous input (from source domain)
    output wire data_out     // Synchronized output (safe in dst domain)
);

    // Synchronizer chain — synthesis tools should keep these flip-flops
    // close together to minimize routing delay between stages
    (* async_reg = "true" *)  // Vivado/Synopsys attribute
    reg [NUM_STAGES-1:0] sync_chain;

    integer i;

    always @(posedge clk_dst or negedge rst_dst_n) begin
        if (!rst_dst_n) begin
            sync_chain <= {NUM_STAGES{RESET_VAL}};
        end else begin
            sync_chain[0] <= data_in;
            for (i = 1; i < NUM_STAGES; i = i + 1)
                sync_chain[i] <= sync_chain[i-1];
        end
    end

    assign data_out = sync_chain[NUM_STAGES-1];

endmodule


//-----------------------------------------------------------------------------
// Example: Using the synchronizer in a design
//-----------------------------------------------------------------------------
module sync_2ff_usage_example (
    input  wire clk_fast,
    input  wire clk_slow,
    input  wire rst_n,
    input  wire event_pulse,   // Pulse in clk_fast domain
    output wire event_synced   // Synchronized to clk_slow domain
);

    reg event_level;

    // Convert pulse to level toggle in source domain
    always @(posedge clk_fast or negedge rst_n) begin
        if (!rst_n)
            event_level <= 1'b0;
        else if (event_pulse)
            event_level <= ~event_level;
    end

    // Synchronize the level signal to destination domain
    sync_2ff #(
        .RESET_VAL  (1'b0),
        .NUM_STAGES (2)
    ) u_sync (
        .clk_dst   (clk_slow),
        .rst_dst_n (rst_n),
        .data_in   (event_level),
        .data_out  (event_synced)
    );

endmodule
