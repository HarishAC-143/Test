//-----------------------------------------------------------------------------
// Example: Multi-Bit CDC Violation and Gray Code Fix
//
// SpyGlass Rules Triggered:
//   Ac_cdc05 - Multi-bit signal crosses clock domain boundary
//   Ac_cdc04 - Bus signal synchronized bit-by-bit (inadequate)
//
// Multi-bit signals cannot be safely synchronized with per-bit 2-FF
// synchronizers because each bit may resolve at a different cycle,
// producing a corrupted intermediate value.
//
// For counters/pointers: use Gray code encoding (1-bit change per step)
// For arbitrary data: use handshake protocol or async FIFO
//-----------------------------------------------------------------------------

module multibit_cdc_bad (
    input  wire       clk_wr,
    input  wire       clk_rd,
    input  wire       rst_n,
    input  wire       wr_en,
    output reg  [3:0] wr_ptr,
    output reg  [3:0] wr_ptr_synced
);

    // Write pointer increments in clk_wr domain
    always @(posedge clk_wr or negedge rst_n) begin
        if (!rst_n)
            wr_ptr <= 4'b0;
        else if (wr_en)
            wr_ptr <= wr_ptr + 4'd1;
    end

    // BUG: Binary counter crosses domain — multiple bits can change at once
    // Example: 4'b0111 → 4'b1000 — all 4 bits change simultaneously
    // The clk_rd domain might sample: 4'b0000, 4'b1111, or any other combo
    //
    // Even with per-bit synchronizers, each bit resolves independently:
    //   bit[0] might resolve this cycle
    //   bit[3] might resolve next cycle
    //   → corrupted pointer value for 1+ cycles

    reg [3:0] sync1, sync2;

    always @(posedge clk_rd or negedge rst_n) begin
        if (!rst_n) begin
            sync1 <= 4'b0;
            sync2 <= 4'b0;
        end else begin
            sync1 <= wr_ptr;     // Ac_cdc05: multi-bit CDC!
            sync2 <= sync1;
        end
    end

    always @(*) begin
        wr_ptr_synced = sync2;
    end

endmodule


module multibit_cdc_good (
    input  wire       clk_wr,
    input  wire       clk_rd,
    input  wire       rst_n,
    input  wire       wr_en,
    output reg  [3:0] wr_ptr,
    output wire [3:0] wr_ptr_synced
);

    // Binary write pointer (used internally in clk_wr domain)
    always @(posedge clk_wr or negedge rst_n) begin
        if (!rst_n)
            wr_ptr <= 4'b0;
        else if (wr_en)
            wr_ptr <= wr_ptr + 4'd1;
    end

    // FIX: Convert to Gray code before crossing
    // Gray code guarantees only 1 bit changes per increment:
    //   Binary 0111 → Gray 0100
    //   Binary 1000 → Gray 1100
    //   Only bit[3] changes: 0100 → 1100
    wire [3:0] wr_ptr_gray;
    assign wr_ptr_gray = wr_ptr ^ (wr_ptr >> 1);

    // Register the Gray code in the source domain
    reg [3:0] wr_ptr_gray_reg;
    always @(posedge clk_wr or negedge rst_n) begin
        if (!rst_n)
            wr_ptr_gray_reg <= 4'b0;
        else
            wr_ptr_gray_reg <= wr_ptr_gray;
    end

    // Synchronize the Gray-coded pointer (safe — only 1 bit changes)
    reg [3:0] gray_sync1, gray_sync2;
    always @(posedge clk_rd or negedge rst_n) begin
        if (!rst_n) begin
            gray_sync1 <= 4'b0;
            gray_sync2 <= 4'b0;
        end else begin
            gray_sync1 <= wr_ptr_gray_reg;
            gray_sync2 <= gray_sync1;
        end
    end

    // Convert back from Gray to binary in the destination domain
    assign wr_ptr_synced[3] = gray_sync2[3];
    assign wr_ptr_synced[2] = gray_sync2[3] ^ gray_sync2[2];
    assign wr_ptr_synced[1] = gray_sync2[3] ^ gray_sync2[2] ^ gray_sync2[1];
    assign wr_ptr_synced[0] = gray_sync2[3] ^ gray_sync2[2] ^ gray_sync2[1] ^ gray_sync2[0];

endmodule
