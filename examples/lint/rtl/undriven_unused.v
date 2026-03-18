// =============================================================================
// SpyGlass Lint Example: Undriven & Unused Signals (W120, W123, W240)
// =============================================================================
//
// SpyGlass Rules:
//   W120 - Signal is read but never driven (undriven)
//   W123 - Signal is driven but never read (unused)
//   W240 - Internal net is not driven
//   W110 - Input port is not driven
//   W116 - Output port is not loaded (unused by parent)
//   W287 - Unconnected port in instance
//
// These rules catch connectivity issues that indicate wiring mistakes,
// leftover signals from refactoring, or incomplete designs.
//
// Run with: current_goal lint/lint_rtl
// =============================================================================

module connectivity_buggy (
    input        clk,
    input        rst_n,
    input  [7:0] data_in,
    input  [3:0] config,      // W123: 'config' is never used
    output [7:0] data_out,
    output       status,      // W240: 'status' is never driven
    output [3:0] debug_flags  // W123: 'debug_flags' driven but never read externally
);

    reg  [7:0] data_reg;
    wire [7:0] processed;
    wire       error_flag;    // W120: read but never driven
    wire [3:0] reserved;      // W240: declared but never driven or read

    // data_reg is used properly
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            data_reg <= 8'h0;
        else
            data_reg <= data_in;
    end

    assign processed = data_reg;

    // W120: error_flag is read here but was never assigned a value
    assign data_out = error_flag ? 8'hFF : processed;

    // 'debug_flags' is driven but may not be connected at the top level
    assign debug_flags = data_reg[3:0];

    // 'status' output is declared but never driven → W240
    // 'config' input is declared but never read → W123
    // 'reserved' wire is declared but neither driven nor read → W240

endmodule


// Example showing W287: unconnected ports in instance
module sub_module (
    input  [7:0] din,
    input        enable,
    output [7:0] dout,
    output       valid
);
    assign dout  = enable ? din : 8'h0;
    assign valid = enable;
endmodule

module parent_w287 (
    input  [7:0] data,
    output [7:0] result
);

    // W287: 'enable' port not connected, 'valid' port not connected
    sub_module u_sub (
        .din    (data),
        // .enable is missing — W287 / W110 on sub_module
        .dout   (result)
        // .valid is missing — W287 / W116 on sub_module
    );

endmodule
