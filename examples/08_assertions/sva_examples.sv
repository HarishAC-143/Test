// SystemVerilog Assertions (SVA) Examples
// Assertions verify design intent and catch bugs during simulation.
// They can also be used by formal verification tools.

module sva_examples (
    input  logic       clk,
    input  logic       rst_n,
    input  logic       req,
    input  logic       ack,
    input  logic       grant,
    input  logic [7:0] data,
    input  logic       valid,
    input  logic       ready
);

    // =========================================================================
    // IMMEDIATE ASSERTIONS - checked at a point in procedural code
    // =========================================================================

    always_comb begin
        // Data must not be X when valid is asserted
        if (valid) begin
            assert (!$isunknown(data))
                else $error("Data contains X/Z when valid is high");
        end
    end

    // =========================================================================
    // CONCURRENT ASSERTIONS - checked continuously across clock cycles
    // =========================================================================

    // --- Simple property: req must be followed by ack within 5 cycles ---
    property p_req_ack;
        @(posedge clk) disable iff (!rst_n)
            req |-> ##[1:5] ack;
    endproperty
    assert property (p_req_ack)
        else $error("ACK not received within 5 cycles of REQ");

    // --- req must stay high until ack ---
    property p_req_stable;
        @(posedge clk) disable iff (!rst_n)
            (req && !ack) |=> req;
    endproperty
    assert property (p_req_stable)
        else $error("REQ deasserted before ACK");

    // --- Handshake: valid must not drop without ready ---
    property p_valid_until_ready;
        @(posedge clk) disable iff (!rst_n)
            (valid && !ready) |=> valid;
    endproperty
    assert property (p_valid_until_ready)
        else $error("Valid dropped before ready handshake");

    // --- Data must be stable while valid is high and ready is low ---
    property p_data_stable;
        @(posedge clk) disable iff (!rst_n)
            (valid && !ready) |=> ($stable(data));
    endproperty
    assert property (p_data_stable)
        else $error("Data changed while waiting for handshake");

    // --- No two grants in consecutive cycles ---
    property p_no_back_to_back_grant;
        @(posedge clk) disable iff (!rst_n)
            grant |=> !grant;
    endproperty
    assert property (p_no_back_to_back_grant)
        else $error("Back-to-back grants detected");

    // --- After reset deasserts, req must be low for at least 4 cycles ---
    property p_reset_recovery;
        @(posedge clk)
            $rose(rst_n) |-> ##[0:3] !req;
    endproperty
    assert property (p_reset_recovery)
        else $warning("REQ asserted too soon after reset");

    // =========================================================================
    // COVER PROPERTIES - track if interesting scenarios occur
    // =========================================================================

    cover property (@(posedge clk) disable iff (!rst_n)
        req ##[1:3] ack
    );

    cover property (@(posedge clk) disable iff (!rst_n)
        valid && ready
    );

    // =========================================================================
    // SEQUENCES - reusable temporal patterns
    // =========================================================================

    sequence s_handshake;
        valid && ready;
    endsequence

    sequence s_burst_of_4;
        valid [*4];
    endsequence

    // Use sequences in properties
    property p_burst_ends_properly;
        @(posedge clk) disable iff (!rst_n)
            s_burst_of_4 |-> ##1 !valid;
    endproperty

endmodule
