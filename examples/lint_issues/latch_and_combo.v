// =============================================================================
// Example 2: Latch Inference & Combinational Loop Issues
// =============================================================================
// This module demonstrates lint violations related to unintended latches
// and combinational feedback loops — two of the most serious RTL design bugs.
//
// SpyGlass will report:
//   W_LATCH      — Unintended latch inference from incomplete branching
//   W_COMBO_LOOP — Combinational feedback loop
//   SYNTH_5130   — Non-synthesizable construct
//   W_MULTI_DRIVE— Multiple drivers on a single signal
// =============================================================================

module latch_and_combo (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [1:0]  sel,
    input  wire [7:0]  data_a,
    input  wire [7:0]  data_b,
    input  wire [7:0]  data_c,
    output reg  [7:0]  mux_out,
    output reg  [7:0]  result,
    output wire [7:0]  feedback_out
);

    wire [7:0] combo_node;

    // -------------------------------------------------------------------------
    // ISSUE 1: W_LATCH — Incomplete case statement
    //
    // The case statement covers sel values 2'b00, 2'b01, 2'b10, but NOT 2'b11.
    // When sel == 2'b11, mux_out must retain its previous value → latch inferred.
    //
    // SpyGlass reports:
    //   "Latch inferred for signal 'mux_out' due to incomplete case statement."
    //
    // This is a synthesis hazard: the designer likely intended a MUX, not a latch.
    // -------------------------------------------------------------------------
    always @(*) begin
        case (sel)
            2'b00: mux_out = data_a;
            2'b01: mux_out = data_b;
            2'b10: mux_out = data_c;
            // Missing: 2'b11 branch → latch!
        endcase
    end

    // -------------------------------------------------------------------------
    // ISSUE 2: W_LATCH — Incomplete if-else
    //
    // The if-else chain does not have a final else clause. When sel == 2'b11,
    // 'result' retains its value → latch inferred.
    // -------------------------------------------------------------------------
    always @(*) begin
        if (sel == 2'b00)
            result = data_a + data_b;
        else if (sel == 2'b01)
            result = data_a - data_b;
        else if (sel == 2'b10)
            result = data_a & data_b;
        // Missing: else clause → latch on 'result'!
    end

    // -------------------------------------------------------------------------
    // ISSUE 3: W_COMBO_LOOP — Combinational feedback loop
    //
    // 'combo_node' depends on 'feedback_out', which in turn depends on
    // 'combo_node'. There is no flip-flop in this path, creating an
    // oscillation risk in hardware.
    //
    // SpyGlass reports:
    //   "Combinational loop detected involving signal 'combo_node'."
    //
    // In real hardware, this creates a race condition. The output is
    // indeterminate and depends on gate delays.
    // -------------------------------------------------------------------------
    assign combo_node   = data_a ^ feedback_out;
    assign feedback_out = combo_node | data_b;

    // -------------------------------------------------------------------------
    // ISSUE 4: SYNTH_5130 — Non-synthesizable construct
    //
    // initial blocks and #delay are simulation-only constructs.
    // They cannot be mapped to hardware gates.
    //
    // SpyGlass reports:
    //   "Non-synthesizable construct found: initial block"
    //   "Non-synthesizable construct found: delay (#10)"
    // -------------------------------------------------------------------------
    reg [7:0] sim_only_reg;

    initial begin
        sim_only_reg = 8'h00;
        #10;
        sim_only_reg = 8'hFF;
    end

endmodule
