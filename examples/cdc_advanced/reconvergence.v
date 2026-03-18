//-----------------------------------------------------------------------------
// Example: CDC Reconvergence
//
// SpyGlass Rules Triggered:
//   Ac_cdc07 - Reconvergence of synchronized CDC signals
//   Ac_cdc08 - Data/control coherency issue at reconvergence point
//
// When multiple signals from the same source domain are independently
// synchronized to the destination domain, they may arrive at different
// times (up to 1 destination clock cycle apart). If they later
// reconverge (feed into the same logic), the logic may operate on
// an inconsistent snapshot of the source domain.
//
// This is one of the subtlest CDC issues — each individual crossing
// is properly synchronized, but the combination is still unsafe.
//-----------------------------------------------------------------------------

module reconvergence_bad (
    input  wire       clk_a,
    input  wire       clk_b,
    input  wire       rst_n,
    input  wire       sel_a,          // Select signal in domain A
    input  wire [7:0] data_a,         // Data signal in domain A
    input  wire [7:0] data_b_local,   // Data in domain B
    output reg  [7:0] result
);

    // Synchronize sel_a → domain B
    reg sel_sync1, sel_sync2;
    always @(posedge clk_b or negedge rst_n) begin
        if (!rst_n) begin
            sel_sync1 <= 1'b0;
            sel_sync2 <= 1'b0;
        end else begin
            sel_sync1 <= sel_a;
            sel_sync2 <= sel_sync1;
        end
    end

    // Synchronize data_a[0] → domain B (just bit 0 as a simplified example)
    reg data_sync1, data_sync2;
    always @(posedge clk_b or negedge rst_n) begin
        if (!rst_n) begin
            data_sync1 <= 1'b0;
            data_sync2 <= 1'b0;
        end else begin
            data_sync1 <= data_a[0];
            data_sync2 <= data_sync1;
        end
    end

    // BUG: sel_sync2 and data_sync2 are both from domain A, but they
    // pass through independent synchronizers. sel_sync2 might update
    // one cycle before data_sync2 (or vice versa).
    //
    // Example failure scenario:
    //   Cycle N:   sel_a=0, data_a[0]=1 in domain A
    //   Cycle N+1: sel_a=1, data_a[0]=0 in domain A (both change)
    //   In domain B: sel_sync2 updates to 1, but data_sync2 still shows 1
    //   → result uses wrong sel/data combination
    always @(posedge clk_b or negedge rst_n) begin
        if (!rst_n)
            result <= 8'b0;
        else if (sel_sync2)                        // Ac_cdc07: reconvergence!
            result <= {7'b0, data_sync2};
        else
            result <= data_b_local;
    end

endmodule


module reconvergence_good (
    input  wire       clk_a,
    input  wire       clk_b,
    input  wire       rst_n,
    input  wire       sel_a,
    input  wire [7:0] data_a,
    input  wire [7:0] data_b_local,
    output reg  [7:0] result
);

    // FIX: Use a handshake or FIFO to transfer sel and data as a
    // coherent bundle. Here we use a simple req/ack handshake.

    reg        req_a;
    reg        sel_a_held;
    reg [7:0]  data_a_held;

    // Source domain: capture both signals atomically
    always @(posedge clk_a or negedge rst_n) begin
        if (!rst_n) begin
            req_a       <= 1'b0;
            sel_a_held  <= 1'b0;
            data_a_held <= 8'b0;
        end else if (!req_a) begin
            sel_a_held  <= sel_a;
            data_a_held <= data_a;
            req_a       <= 1'b1;
        end else if (ack_synced) begin
            req_a <= 1'b0;
        end
    end

    // Synchronize req → domain B
    reg req_sync1, req_sync2, req_sync2_d;
    always @(posedge clk_b or negedge rst_n) begin
        if (!rst_n) begin
            req_sync1  <= 1'b0;
            req_sync2  <= 1'b0;
            req_sync2_d <= 1'b0;
        end else begin
            req_sync1  <= req_a;
            req_sync2  <= req_sync1;
            req_sync2_d <= req_sync2;
        end
    end

    wire req_rising = req_sync2 && !req_sync2_d;

    // Synchronize ack → domain A
    reg ack_b;
    reg ack_sync1, ack_sync2;
    wire ack_synced;
    always @(posedge clk_a or negedge rst_n) begin
        if (!rst_n) begin
            ack_sync1 <= 1'b0;
            ack_sync2 <= 1'b0;
        end else begin
            ack_sync1 <= ack_b;
            ack_sync2 <= ack_sync1;
        end
    end
    assign ack_synced = ack_sync2;

    // Destination domain: capture data on req rising edge
    always @(posedge clk_b or negedge rst_n) begin
        if (!rst_n) begin
            result <= 8'b0;
            ack_b  <= 1'b0;
        end else begin
            if (req_rising) begin
                // Data is stable because source holds it while req is high
                if (sel_a_held)
                    result <= data_a_held;
                else
                    result <= data_b_local;
                ack_b <= 1'b1;
            end
            if (!req_sync2)
                ack_b <= 1'b0;
        end
    end

endmodule
