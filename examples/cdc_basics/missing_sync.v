//-----------------------------------------------------------------------------
// Example: Missing CDC Synchronizer
//
// SpyGlass Rules Triggered:
//   Ac_cdc01 - Signal crosses clock domain boundary without synchronizer
//   Ac_cdc02 - Insufficient synchronization stages
//
// The most basic and most dangerous CDC violation: a signal generated
// in one clock domain is directly sampled by a flip-flop in another
// domain without any synchronization.
//-----------------------------------------------------------------------------

module missing_sync_bad (
    input  wire clk_a,        // Source domain clock
    input  wire clk_b,        // Destination domain clock
    input  wire rst_n,
    input  wire start,        // Signal in clk_a domain
    output reg  req_captured  // Signal in clk_b domain
);

    reg req;

    // Source domain: generate request signal
    always @(posedge clk_a or negedge rst_n) begin
        if (!rst_n)
            req <= 1'b0;
        else
            req <= start;
    end

    // BUG: clk_b domain directly samples a clk_a-domain signal
    // If req changes near clk_b's setup/hold window, the flip-flop
    // may go metastable → unpredictable output for some time
    always @(posedge clk_b or negedge rst_n) begin
        if (!rst_n)
            req_captured <= 1'b0;
        else
            req_captured <= req;    // Ac_cdc01: no synchronizer!
    end

endmodule


module missing_sync_good (
    input  wire clk_a,
    input  wire clk_b,
    input  wire rst_n,
    input  wire start,
    output wire req_captured
);

    reg req;

    // Source domain: generate request signal
    always @(posedge clk_a or negedge rst_n) begin
        if (!rst_n)
            req <= 1'b0;
        else
            req <= start;
    end

    // FIX: 2-FF synchronizer in destination domain
    reg req_sync1, req_sync2;

    always @(posedge clk_b or negedge rst_n) begin
        if (!rst_n) begin
            req_sync1 <= 1'b0;
            req_sync2 <= 1'b0;
        end else begin
            req_sync1 <= req;        // First sync stage (may go metastable)
            req_sync2 <= req_sync1;  // Second sync stage (resolves metastability)
        end
    end

    // Use the synchronized version — safe in clk_b domain
    assign req_captured = req_sync2;

endmodule
