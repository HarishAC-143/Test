// =============================================================================
// SpyGlass CDC Example: Multi-Bit Crossing Without Gray Code (Ac_cdc02)
// =============================================================================
//
// SpyGlass Rule: Ac_cdc02
// Severity:      Error
// Category:      Clock Domain Crossing
//
// A multi-bit bus crosses from one clock domain to another using standard
// binary encoding. When multiple bits change simultaneously (e.g., binary
// counter 011 → 100 where all 3 bits toggle), the destination synchronizer
// may capture an intermediate value (e.g., 000, 001, 010, 100, 101, 110,
// or 111) because each bit's synchronizer may resolve independently.
//
// Run with: current_goal cdc/cdc_verify
// =============================================================================

module multibit_crossing (
    input        clk_a,
    input        rst_a_n,
    input        clk_b,
    input        rst_b_n,
    input  [3:0] wptr_bin,     // Binary write pointer from clk_a domain
    output reg [3:0] wptr_sync // Synchronized pointer in clk_b domain
);

    reg [3:0] sync1, sync2;

    // Ac_cdc02 VIOLATION:
    // wptr_bin is a 4-bit binary value. When transitioning from,
    // for example, 0111 to 1000, all four bits change simultaneously.
    // The two-stage synchronizer may capture any combination of old
    // and new bit values, producing a garbled pointer.
    //
    // Example failure scenario:
    //   wptr_bin transitions from 4'b0111 (7) to 4'b1000 (8)
    //   sync1 might capture 4'b0000 (0), 4'b1111 (15), or any value
    //   This causes incorrect full/empty flag computation in an async FIFO
    always @(posedge clk_b or negedge rst_b_n) begin
        if (!rst_b_n) begin
            sync1     <= 4'b0;
            sync2     <= 4'b0;
            wptr_sync <= 4'b0;
        end else begin
            sync1     <= wptr_bin;  // MULTI-BIT BINARY CROSSING!
            sync2     <= sync1;
            wptr_sync <= sync2;
        end
    end

endmodule
