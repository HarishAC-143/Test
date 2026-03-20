// ============================================================================
// SystemVerilog Assertions (SVA) — FIFO Protocol Checker
// ============================================================================
// This module demonstrates immediate and concurrent assertions for
// verifying FIFO interface protocols. Assertions are not synthesizable
// but live alongside RTL to catch bugs during simulation.
//
// Bind this module to any FIFO instance:
//   bind sync_fifo fifo_assertions #(.WIDTH(WIDTH), .DEPTH(DEPTH))
//       u_assert (.*);
// ============================================================================

module fifo_assertions #(
    parameter int WIDTH = 8,
    parameter int DEPTH = 16
)(
    input logic             clk,
    input logic             rst_n,
    input logic             wr_en,
    input logic             rd_en,
    input logic [WIDTH-1:0] wr_data,
    input logic [WIDTH-1:0] rd_data,
    input logic             full,
    input logic             empty,
    input logic [$clog2(DEPTH):0] count
);

    // -------------------------------------------------------------------------
    // Concurrent Assertions
    // -------------------------------------------------------------------------

    // Never write to a full FIFO
    property p_no_write_when_full;
        @(posedge clk) disable iff (!rst_n)
        full |-> !wr_en;
    endproperty
    assert property (p_no_write_when_full)
        else $error("[FIFO] Write attempted while full!");

    // Never read from an empty FIFO
    property p_no_read_when_empty;
        @(posedge clk) disable iff (!rst_n)
        empty |-> !rd_en;
    endproperty
    assert property (p_no_read_when_empty)
        else $error("[FIFO] Read attempted while empty!");

    // Count must never exceed DEPTH
    property p_count_range;
        @(posedge clk) disable iff (!rst_n)
        count <= DEPTH;
    endproperty
    assert property (p_count_range)
        else $error("[FIFO] Count %0d exceeds DEPTH %0d!", count, DEPTH);

    // Full should be asserted when count == DEPTH
    property p_full_correct;
        @(posedge clk) disable iff (!rst_n)
        (count == DEPTH) |-> full;
    endproperty
    assert property (p_full_correct)
        else $error("[FIFO] count==DEPTH but full not asserted!");

    // Empty should be asserted when count == 0
    property p_empty_correct;
        @(posedge clk) disable iff (!rst_n)
        (count == 0) |-> empty;
    endproperty
    assert property (p_empty_correct)
        else $error("[FIFO] count==0 but empty not asserted!");

    // After reset, FIFO should be empty
    property p_reset_empty;
        @(posedge clk)
        !rst_n |=> empty && !full && (count == 0);
    endproperty
    assert property (p_reset_empty)
        else $error("[FIFO] Not empty after reset!");

    // -------------------------------------------------------------------------
    // Cover Properties — ensure scenarios are reachable
    // -------------------------------------------------------------------------

    cover property (@(posedge clk) disable iff (!rst_n)
        full && wr_en);

    cover property (@(posedge clk) disable iff (!rst_n)
        empty && rd_en);

    cover property (@(posedge clk) disable iff (!rst_n)
        wr_en && rd_en && !full && !empty);

    cover property (@(posedge clk) disable iff (!rst_n)
        $rose(full));

    cover property (@(posedge clk) disable iff (!rst_n)
        $rose(empty));

endmodule
