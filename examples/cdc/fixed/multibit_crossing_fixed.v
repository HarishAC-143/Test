// =============================================================================
// SpyGlass CDC Fix: Multi-Bit Crossing (Ac_cdc02) — Corrected
// =============================================================================
//
// The binary pointer is converted to Gray code in the source domain
// before crossing. Gray code guarantees only one bit changes per
// increment, making it safe for two-flop synchronization. The
// synchronized Gray code is then converted back to binary in the
// destination domain.
// =============================================================================

module multibit_crossing_fixed #(
    parameter WIDTH = 4
)(
    input                clk_a,
    input                rst_a_n,
    input                clk_b,
    input                rst_b_n,
    input  [WIDTH-1:0]   wptr_bin,       // Binary pointer from clk_a domain
    output [WIDTH-1:0]   wptr_sync_bin   // Synchronized binary pointer in clk_b
);

    // =========================================================================
    // Step 1: Convert binary to Gray code in source domain
    // =========================================================================
    wire [WIDTH-1:0] wptr_gray;
    assign wptr_gray = wptr_bin ^ (wptr_bin >> 1);

    // =========================================================================
    // Step 2: Two-flop synchronize the Gray-coded pointer
    // =========================================================================
    reg [WIDTH-1:0] sync1, sync2;

    always @(posedge clk_b or negedge rst_b_n) begin
        if (!rst_b_n) begin
            sync1 <= {WIDTH{1'b0}};
            sync2 <= {WIDTH{1'b0}};
        end else begin
            sync1 <= wptr_gray;  // Only 1 bit changes at a time — safe!
            sync2 <= sync1;
        end
    end

    // =========================================================================
    // Step 3: Convert Gray code back to binary in destination domain
    // =========================================================================
    // Gray-to-binary conversion: each binary bit is the XOR of all
    // Gray bits from that position to the MSB.
    genvar i;
    generate
        for (i = 0; i < WIDTH; i = i + 1) begin : gray2bin
            assign wptr_sync_bin[i] = ^(sync2 >> i);
        end
    endgenerate

endmodule
