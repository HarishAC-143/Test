// Common SystemVerilog assertion patterns for RTL verification.
// These assertions are typically placed inside the design or in a bind module.

module assertion_examples (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        req,
    input  logic        ack,
    input  logic        grant,
    input  logic        valid,
    input  logic        ready,
    input  logic [7:0]  data,
    input  logic        fifo_push,
    input  logic        fifo_pop,
    input  logic        fifo_full,
    input  logic        fifo_empty
);

    // =========================================================================
    // 1. Request must be acknowledged within 1-4 cycles
    // =========================================================================
    property p_req_ack;
        @(posedge clk) disable iff (!rst_n)
        req |-> ##[1:4] ack;
    endproperty

    assert property (p_req_ack)
    else $error("[%0t] REQ not acknowledged within 4 cycles", $time);

    // =========================================================================
    // 2. Valid must stay high until ready (handshake protocol)
    // =========================================================================
    property p_valid_until_ready;
        @(posedge clk) disable iff (!rst_n)
        (valid && !ready) |=> valid;
    endproperty

    assert property (p_valid_until_ready)
    else $error("[%0t] Valid dropped before ready", $time);

    // =========================================================================
    // 3. Data must be stable while valid is asserted (no data change mid-handshake)
    // =========================================================================
    property p_data_stable;
        @(posedge clk) disable iff (!rst_n)
        (valid && !ready) |=> (data == $past(data));
    endproperty

    assert property (p_data_stable)
    else $error("[%0t] Data changed while valid & !ready", $time);

    // =========================================================================
    // 4. No push when FIFO is full
    // =========================================================================
    property p_no_push_when_full;
        @(posedge clk) disable iff (!rst_n)
        fifo_full |-> !fifo_push;
    endproperty

    assert property (p_no_push_when_full)
    else $error("[%0t] Push attempted on full FIFO", $time);

    // =========================================================================
    // 5. No pop when FIFO is empty
    // =========================================================================
    property p_no_pop_when_empty;
        @(posedge clk) disable iff (!rst_n)
        fifo_empty |-> !fifo_pop;
    endproperty

    assert property (p_no_pop_when_empty)
    else $error("[%0t] Pop attempted on empty FIFO", $time);

    // =========================================================================
    // 6. Grant must follow request (no spurious grants)
    // =========================================================================
    property p_grant_after_req;
        @(posedge clk) disable iff (!rst_n)
        grant |-> $past(req, 1) || $past(req, 2);
    endproperty

    assert property (p_grant_after_req)
    else $error("[%0t] Grant without prior request", $time);

    // =========================================================================
    // 7. One-hot check — exactly one bit set
    // =========================================================================
    property p_onehot;
        @(posedge clk) disable iff (!rst_n)
        valid |-> $onehot(data) || (data == '0);
    endproperty
    // (Typically used for state registers or arbitration)

    // =========================================================================
    // 8. Cover property — observe interesting scenarios
    // =========================================================================
    cover property (@(posedge clk) disable iff (!rst_n)
        req ##1 ack ##1 grant
    );

    cover property (@(posedge clk) disable iff (!rst_n)
        fifo_full ##1 fifo_pop ##1 !fifo_full
    );

endmodule
