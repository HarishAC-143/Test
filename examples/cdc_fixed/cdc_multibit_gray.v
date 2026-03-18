// =============================================================================
// Example 5 — FIXED: Multi-Bit CDC with Gray Code Encoding
// =============================================================================
// Compare with: examples/cdc_issues/cdc_multibit_bad.v
//
// Fix: Convert binary counter to Gray code BEFORE crossing, synchronize
// the Gray-coded value with a 2-FF synchronizer, then convert back to
// binary in the destination domain.
//
// Gray code property: Only ONE bit changes between consecutive values.
// Even if sampled at the "wrong" time, the captured value is either the
// old value or the new value — never an invalid intermediate.
// =============================================================================

module cdc_multibit_gray (
    // Domain A
    input  wire       clk_a,
    input  wire       rst_a_n,
    input  wire       count_en,

    // Domain B
    input  wire       clk_b,
    input  wire       rst_b_n,
    output wire [3:0] counter_b_sync
);

    // =========================================================================
    // Clock Domain A — Binary Counter + Gray Encoding
    // =========================================================================
    reg [3:0] counter_a;
    reg [3:0] counter_a_gray;

    always @(posedge clk_a or negedge rst_a_n) begin
        if (!rst_a_n)
            counter_a <= 4'd0;
        else if (count_en)
            counter_a <= counter_a + 1'b1;
    end

    // Binary-to-Gray conversion (registered in source domain)
    // Gray = Binary XOR (Binary >> 1)
    //
    // Binary: 0000 0001 0010 0011 0100 0101 0110 0111
    // Gray:   0000 0001 0011 0010 0110 0111 0101 0100
    always @(posedge clk_a or negedge rst_a_n) begin
        if (!rst_a_n)
            counter_a_gray <= 4'd0;
        else
            counter_a_gray <= counter_a ^ (counter_a >> 1);
    end

    // =========================================================================
    // Clock Domain B — 2-FF Synchronizer + Gray-to-Binary Decode
    // =========================================================================

    // Standard 2-FF synchronizer — safe for Gray-coded multi-bit signal
    // because only one bit changes at a time
    reg [3:0] gray_sync1, gray_sync2;

    always @(posedge clk_b or negedge rst_b_n) begin
        if (!rst_b_n) begin
            gray_sync1 <= 4'd0;
            gray_sync2 <= 4'd0;
        end else begin
            gray_sync1 <= counter_a_gray;    // Safe: only 1 bit changes
            gray_sync2 <= gray_sync1;
        end
    end

    // Gray-to-Binary conversion
    // binary[i] = XOR of gray[N-1:i]
    //
    // For 4-bit:
    //   binary[3] = gray[3]
    //   binary[2] = gray[3] ^ gray[2]
    //   binary[1] = gray[3] ^ gray[2] ^ gray[1]
    //   binary[0] = gray[3] ^ gray[2] ^ gray[1] ^ gray[0]
    assign counter_b_sync[3] = gray_sync2[3];
    assign counter_b_sync[2] = gray_sync2[3] ^ gray_sync2[2];
    assign counter_b_sync[1] = gray_sync2[3] ^ gray_sync2[2] ^ gray_sync2[1];
    assign counter_b_sync[0] = gray_sync2[3] ^ gray_sync2[2] ^ gray_sync2[1] ^ gray_sync2[0];

    // Note: The synchronized counter value in domain B may lag behind
    // the actual counter_a value by 2-3 clk_b cycles. This is expected
    // and acceptable for pointer comparison (e.g., FIFO full/empty).

endmodule
