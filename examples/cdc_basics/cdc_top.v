//-----------------------------------------------------------------------------
// Example: Top-Level CDC Testbed
//
// Instantiates multiple CDC scenarios for SpyGlass analysis.
// This module serves as the top-level for running cdc_setup and
// cdc_verify goals.
//
// Contains both intentionally buggy and correctly synchronized paths
// so you can see SpyGlass flag the bad ones and pass the good ones.
//-----------------------------------------------------------------------------

module cdc_top (
    input  wire       clk_a,        // Clock domain A (e.g., 100 MHz)
    input  wire       clk_b,        // Clock domain B (e.g., 133 MHz)
    input  wire       rst_n,        // Global async reset

    // Control signals (clk_a domain)
    input  wire       start,
    input  wire       wr_en,
    input  wire [7:0] data_in,

    // Outputs (clk_b domain)
    output wire       req_out_bad,     // From unsynchronized path
    output wire       req_out_good,    // From synchronized path
    output wire [3:0] wr_ptr_out_bad,  // From binary multi-bit crossing
    output wire [3:0] wr_ptr_out_good  // From gray-coded crossing
);

    //=========================================================================
    // Scenario 1: Missing synchronizer (BAD)
    //=========================================================================
    reg req_a;
    reg req_captured_bad;

    always @(posedge clk_a or negedge rst_n) begin
        if (!rst_n)
            req_a <= 1'b0;
        else
            req_a <= start;
    end

    // Direct crossing — SpyGlass will flag Ac_cdc01
    always @(posedge clk_b or negedge rst_n) begin
        if (!rst_n)
            req_captured_bad <= 1'b0;
        else
            req_captured_bad <= req_a;  // No synchronizer!
    end

    assign req_out_bad = req_captured_bad;

    //=========================================================================
    // Scenario 2: Proper 2-FF synchronizer (GOOD)
    //=========================================================================
    reg req_sync1, req_sync2;

    always @(posedge clk_b or negedge rst_n) begin
        if (!rst_n) begin
            req_sync1 <= 1'b0;
            req_sync2 <= 1'b0;
        end else begin
            req_sync1 <= req_a;
            req_sync2 <= req_sync1;
        end
    end

    assign req_out_good = req_sync2;

    //=========================================================================
    // Scenario 3: Multi-bit binary crossing (BAD)
    //=========================================================================
    multibit_cdc_bad u_multibit_bad (
        .clk_wr        (clk_a),
        .clk_rd        (clk_b),
        .rst_n         (rst_n),
        .wr_en         (wr_en),
        .wr_ptr        (),
        .wr_ptr_synced (wr_ptr_out_bad)
    );

    //=========================================================================
    // Scenario 4: Multi-bit gray-code crossing (GOOD)
    //=========================================================================
    multibit_cdc_good u_multibit_good (
        .clk_wr        (clk_a),
        .clk_rd        (clk_b),
        .rst_n         (rst_n),
        .wr_en         (wr_en),
        .wr_ptr        (),
        .wr_ptr_synced (wr_ptr_out_good)
    );

endmodule
