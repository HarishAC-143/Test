// =============================================================================
// Intentional CDC Violations — For Educational Purposes
// =============================================================================
// This file contains intentional CDC violations to demonstrate what SpyGlass
// catches. Each violation is annotated with the corresponding rule.
//
// DO NOT use these patterns in real designs!
// =============================================================================

// -----------------------------------------------------------------------------
// Violation 1: Missing Synchronizer (Ac_cdc01)
// -----------------------------------------------------------------------------
// A signal crosses from clk_a to clk_b with no synchronizer at all.
// This is the most basic and dangerous CDC violation.
// -----------------------------------------------------------------------------
module cdc_viol_no_sync (
    input  wire clk_a,
    input  wire clk_b,
    input  wire rst_n,
    input  wire data_a,
    output reg  data_b
);

    reg data_a_reg;

    always @(posedge clk_a or negedge rst_n) begin
        if (!rst_n)
            data_a_reg <= 1'b0;
        else
            data_a_reg <= data_a;
    end

    // Ac_cdc01: VIOLATION — direct crossing, no synchronizer!
    always @(posedge clk_b or negedge rst_n) begin
        if (!rst_n)
            data_b <= 1'b0;
        else
            data_b <= data_a_reg;    // Metastability risk!
    end

endmodule

// -----------------------------------------------------------------------------
// Violation 2: Multi-Bit CDC Without Encoding (Ac_cdc03)
// -----------------------------------------------------------------------------
// A multi-bit counter crosses domains with simple bit-by-bit synchronization.
// Different bits may be captured at different clock edges, producing glitched
// intermediate values.
// -----------------------------------------------------------------------------
module cdc_viol_multibit (
    input  wire       clk_a,
    input  wire       clk_b,
    input  wire       rst_n,
    input  wire       inc,
    output reg  [3:0] count_b
);

    reg [3:0] count_a;

    always @(posedge clk_a or negedge rst_n) begin
        if (!rst_n)
            count_a <= 4'b0;
        else if (inc)
            count_a <= count_a + 4'd1;
    end

    // Ac_cdc03: VIOLATION — multi-bit bus synchronized without Gray code!
    // Example: count_a transitions from 4'b0111 to 4'b1000
    //   Bit 3 captured new: 1  ┐
    //   Bit 2 captured old: 1  │ sync1 sees 4'b1111 — WRONG!
    //   Bit 1 captured old: 1  │
    //   Bit 0 captured old: 1  ┘
    reg [3:0] sync1, sync2;

    always @(posedge clk_b or negedge rst_n) begin
        if (!rst_n) begin
            sync1   <= 4'b0;
            sync2   <= 4'b0;
            count_b <= 4'b0;
        end else begin
            sync1   <= count_a;   // Multi-bit crossing — dangerous!
            sync2   <= sync1;
            count_b <= sync2;
        end
    end

endmodule

// -----------------------------------------------------------------------------
// Violation 3: Combinational Logic Before Synchronizer (Ac_cdc02)
// -----------------------------------------------------------------------------
// Combinational logic between the source register and synchronizer input
// can produce glitches. The synchronizer may capture a glitch as valid data.
// -----------------------------------------------------------------------------
module cdc_viol_combo_before_sync (
    input  wire clk_a,
    input  wire clk_b,
    input  wire rst_n,
    input  wire sig_a1,
    input  wire sig_a2,
    output reg  result_b
);

    reg reg_a1, reg_a2;

    always @(posedge clk_a or negedge rst_n) begin
        if (!rst_n) begin
            reg_a1 <= 1'b0;
            reg_a2 <= 1'b0;
        end else begin
            reg_a1 <= sig_a1;
            reg_a2 <= sig_a2;
        end
    end

    // Ac_cdc02: VIOLATION — AND gate between source flops and synchronizer
    // When reg_a1 and reg_a2 change at the same edge but have different
    // propagation delays, the AND output can glitch briefly.
    wire combo = reg_a1 & reg_a2;

    reg sync1, sync2;

    always @(posedge clk_b or negedge rst_n) begin
        if (!rst_n) begin
            sync1    <= 1'b0;
            sync2    <= 1'b0;
            result_b <= 1'b0;
        end else begin
            sync1    <= combo;     // May capture glitch!
            sync2    <= sync1;
            result_b <= sync2;
        end
    end

endmodule

// -----------------------------------------------------------------------------
// Violation 4: Reconvergent CDC Paths (Ac_conv01)
// -----------------------------------------------------------------------------
// Two signals from the same source domain cross independently and reconverge
// in the destination domain. They may be captured on different clock cycles,
// creating a window of inconsistency.
// -----------------------------------------------------------------------------
module cdc_viol_reconvergence (
    input  wire clk_a,
    input  wire clk_b,
    input  wire rst_n,
    input  wire data_a,
    input  wire valid_a,
    output wire result_b
);

    reg data_a_reg, valid_a_reg;

    always @(posedge clk_a or negedge rst_n) begin
        if (!rst_n) begin
            data_a_reg  <= 1'b0;
            valid_a_reg <= 1'b0;
        end else begin
            data_a_reg  <= data_a;
            valid_a_reg <= valid_a;
        end
    end

    // Two separate synchronizers
    reg data_sync1, data_sync2;
    reg valid_sync1, valid_sync2;

    always @(posedge clk_b or negedge rst_n) begin
        if (!rst_n) begin
            data_sync1  <= 1'b0;
            data_sync2  <= 1'b0;
            valid_sync1 <= 1'b0;
            valid_sync2 <= 1'b0;
        end else begin
            data_sync1  <= data_a_reg;
            data_sync2  <= data_sync1;
            valid_sync1 <= valid_a_reg;
            valid_sync2 <= valid_sync1;
        end
    end

    // Ac_conv01: VIOLATION — reconvergence!
    // data_sync2 and valid_sync2 may be from different source clock cycles.
    // If valid goes high one cycle before data changes, the destination
    // might see the OLD data qualified by the NEW valid.
    assign result_b = valid_sync2 & data_sync2;

endmodule

// -----------------------------------------------------------------------------
// Violation 5: Insufficient Pulse Width (Ac_protocol03)
// -----------------------------------------------------------------------------
// A pulse in a fast clock domain is too narrow to be reliably captured by
// a slow clock domain synchronizer.
// -----------------------------------------------------------------------------
module cdc_viol_narrow_pulse (
    input  wire fast_clk,    // 500 MHz
    input  wire slow_clk,    // 50 MHz
    input  wire rst_n,
    input  wire trigger,
    output reg  synced_trigger
);

    reg pulse_fast;

    // Generate a single fast_clk cycle pulse
    always @(posedge fast_clk or negedge rst_n) begin
        if (!rst_n)
            pulse_fast <= 1'b0;
        else
            pulse_fast <= trigger;
    end

    // Ac_protocol03: VIOLATION — pulse may be missed!
    // fast_clk period: 2ns, slow_clk period: 20ns
    // A 2ns pulse can fall entirely between two slow_clk rising edges.
    reg sync1, sync2;

    always @(posedge slow_clk or negedge rst_n) begin
        if (!rst_n) begin
            sync1          <= 1'b0;
            sync2          <= 1'b0;
            synced_trigger <= 1'b0;
        end else begin
            sync1          <= pulse_fast;    // May miss the pulse entirely!
            sync2          <= sync1;
            synced_trigger <= sync2;
        end
    end

endmodule

// =============================================================================
// Top-level wrapper for CDC violations (for SpyGlass analysis)
// =============================================================================
module cdc_violations_top (
    input  wire clk_a,
    input  wire clk_b,
    input  wire fast_clk,
    input  wire slow_clk,
    input  wire rst_n,
    input  wire data_in,
    input  wire valid_in,
    input  wire sig1,
    input  wire sig2,
    input  wire trigger,
    input  wire inc
);

    wire unused_out1, unused_out2;
    wire [3:0] unused_count;
    reg  unused_data_b;

    cdc_viol_no_sync u_no_sync (
        .clk_a      (clk_a),
        .clk_b      (clk_b),
        .rst_n      (rst_n),
        .data_a     (data_in),
        .data_b     (unused_data_b)
    );

    cdc_viol_multibit u_multibit (
        .clk_a   (clk_a),
        .clk_b   (clk_b),
        .rst_n   (rst_n),
        .inc     (inc),
        .count_b (unused_count)
    );

    cdc_viol_combo_before_sync u_combo (
        .clk_a    (clk_a),
        .clk_b    (clk_b),
        .rst_n    (rst_n),
        .sig_a1   (sig1),
        .sig_a2   (sig2),
        .result_b ()
    );

    cdc_viol_reconvergence u_reconverge (
        .clk_a    (clk_a),
        .clk_b    (clk_b),
        .rst_n    (rst_n),
        .data_a   (data_in),
        .valid_a  (valid_in),
        .result_b (unused_out1)
    );

    cdc_viol_narrow_pulse u_narrow_pulse (
        .fast_clk       (fast_clk),
        .slow_clk       (slow_clk),
        .rst_n          (rst_n),
        .trigger        (trigger),
        .synced_trigger ()
    );

endmodule
