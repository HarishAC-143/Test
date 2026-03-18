// =============================================================================
// SpyGlass Lint Fix: Combinational Loop (W18) — Corrected
// =============================================================================
//
// Combinational loops are broken by inserting registers (flip-flops)
// into the feedback path.
// =============================================================================

module combo_loop_fixed (
    input      clk,
    input      rst_n,
    input      a,
    input      b,
    output reg y
);

    wire mid;
    assign mid = a & y;

    // Register breaks the combinational loop.
    // y is now updated on clock edges, not combinationally.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            y <= 1'b0;
        else
            y <= mid | b;
    end

endmodule


module loop_chain_fixed (
    input      clk,
    input      rst_n,
    input      enable,
    output reg toggle
);

    // Instead of a ring oscillator, use a registered toggle
    // controlled by enable — predictable, synthesizable behavior.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            toggle <= 1'b0;
        else if (enable)
            toggle <= ~toggle;
    end

endmodule


module subtle_loop_fixed (
    input      clk,
    input      rst_n,
    input      sel,
    input      data_in,
    output reg data_out
);

    wire next_val;
    assign next_val = (data_out & sel) | data_in;

    // Register in the feedback path prevents combinational loop.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            data_out <= 1'b0;
        else
            data_out <= next_val;
    end

endmodule
