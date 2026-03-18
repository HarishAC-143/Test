//-----------------------------------------------------------------------------
// Example: Combinational Logic on CDC Path
//
// SpyGlass Rules Triggered:
//   Ac_cdc03 - Combinational logic present on CDC path
//   Ac_cdc03a - Glitch potential on CDC signal
//
// Combinational logic between the source register and the first
// synchronizer flip-flop can produce glitches. A glitch is a transient
// pulse caused by different propagation delays through the logic gates.
//
// Even though glitches settle within one source clock period, the
// destination clock may sample the CDC signal during the glitch,
// capturing an incorrect value. This is NOT the same as metastability —
// the captured value is deterministically wrong.
//-----------------------------------------------------------------------------

module combo_on_cdc_bad (
    input  wire clk_a,
    input  wire clk_b,
    input  wire rst_n,
    input  wire cond_1,       // Condition in domain A
    input  wire cond_2,       // Condition in domain A
    output reg  action        // Action in domain B
);

    reg reg_1, reg_2;

    // Source domain registers
    always @(posedge clk_a or negedge rst_n) begin
        if (!rst_n) begin
            reg_1 <= 1'b0;
            reg_2 <= 1'b0;
        end else begin
            reg_1 <= cond_1;
            reg_2 <= cond_2;
        end
    end

    // BUG: Combinational logic on the CDC path
    // reg_1 and reg_2 change on clk_a edges. The AND gate output
    // can glitch during the transition period.
    //
    // Example glitch scenario (clk_a edge):
    //   Before: reg_1=1, reg_2=1 → AND=1
    //   After:  reg_1=0, reg_2=0 → AND=0
    //   During transition: reg_1 changes first → AND=0 (correct)
    //   But if reg_2 changes first → AND=1→0 (no glitch in this case)
    //   However with more complex logic (XOR, etc.), glitches are common
    wire cdc_signal = reg_1 & reg_2;  // Combinational logic on CDC path

    reg sync1, sync2;
    always @(posedge clk_b or negedge rst_n) begin
        if (!rst_n) begin
            sync1 <= 1'b0;
            sync2 <= 1'b0;
        end else begin
            sync1 <= cdc_signal;  // Ac_cdc03: combo logic before sync!
            sync2 <= sync1;
        end
    end

    always @(posedge clk_b or negedge rst_n) begin
        if (!rst_n)
            action <= 1'b0;
        else
            action <= sync2;
    end

endmodule


module combo_on_cdc_good (
    input  wire clk_a,
    input  wire clk_b,
    input  wire rst_n,
    input  wire cond_1,
    input  wire cond_2,
    output reg  action
);

    reg reg_1, reg_2;

    always @(posedge clk_a or negedge rst_n) begin
        if (!rst_n) begin
            reg_1 <= 1'b0;
            reg_2 <= 1'b0;
        end else begin
            reg_1 <= cond_1;
            reg_2 <= cond_2;
        end
    end

    // FIX: Register the combined signal in the source domain FIRST
    // This eliminates glitches — the registered output is clean
    reg cdc_signal_reg;
    always @(posedge clk_a or negedge rst_n) begin
        if (!rst_n)
            cdc_signal_reg <= 1'b0;
        else
            cdc_signal_reg <= reg_1 & reg_2;
    end

    // Now synchronize the clean, registered signal
    reg sync1, sync2;
    always @(posedge clk_b or negedge rst_n) begin
        if (!rst_n) begin
            sync1 <= 1'b0;
            sync2 <= 1'b0;
        end else begin
            sync1 <= cdc_signal_reg;  // Clean registered source
            sync2 <= sync1;
        end
    end

    always @(posedge clk_b or negedge rst_n) begin
        if (!rst_n)
            action <= 1'b0;
        else
            action <= sync2;
    end

endmodule
