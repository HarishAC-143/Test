//-----------------------------------------------------------------------------
// Example: Undriven and Unloaded Signals
//
// SpyGlass Rules Triggered:
//   W_164  - Signal is not driven (undriven)
//   W_240  - Signal is driven but not loaded (unused)
//   W_287  - Port is unconnected in instantiation
//
// Demonstrates connectivity issues that waste area and often indicate
// real bugs (e.g., forgotten connections during integration).
//-----------------------------------------------------------------------------

module counter_core (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        enable,
    input  wire        load,
    input  wire [7:0]  load_val,
    output reg  [7:0]  count,
    output wire        overflow,
    output wire [3:0]  debug_state    // Output used only for debug
);

    reg [8:0] count_next;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            count <= 8'b0;
        else if (load)
            count <= load_val;
        else if (enable)
            count <= count_next[7:0];
    end

    always @(*) begin
        count_next = {1'b0, count} + 9'd1;
    end

    assign overflow = count_next[8];
    assign debug_state = count[3:0];

endmodule


module counter_top (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       enable,
    output wire [7:0] count_out
);

    wire       overflow;             // W_240: Driven by counter but never used
    wire [3:0] debug_state;          // W_240: Driven by counter but never used
    wire       undriven_signal;      // W_164: Declared but never driven
    wire [7:0] phantom_bus;          // W_164: Declared but never driven

    counter_core u_counter (
        .clk         (clk),
        .rst_n       (rst_n),
        .enable      (enable),
        .load        (1'b0),
        .load_val    (8'b0),
        .count       (count_out),
        .overflow    (overflow),
        .debug_state (debug_state)
    );

    // 'undriven_signal' and 'phantom_bus' are never driven — W_164
    // 'overflow' and 'debug_state' are driven but never read — W_240

endmodule
