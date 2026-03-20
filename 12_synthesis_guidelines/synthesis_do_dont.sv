// ============================================================================
// Synthesis Do's and Don'ts — Annotated Examples
//
// Each section shows a common mistake and its corrected version.
// These patterns apply to all major FPGA families.
// ============================================================================

module synthesis_do_dont (
    input  logic        clk,
    input  logic        rst_n,
    input  logic [3:0]  sel,
    input  logic [7:0]  a, b, c, d,
    input  logic        enable,
    input  logic        mode,
    output logic [7:0]  out_good,
    output logic [7:0]  out_example
);

    // =========================================================================
    // 1. LATCH INFERENCE — Incomplete case/if
    // =========================================================================

    // BAD: Missing default creates a latch
    // always_comb begin
    //     case (sel[1:0])
    //         2'b00: out = a;
    //         2'b01: out = b;
    //         2'b10: out = c;
    //         // 2'b11 missing → latch inferred for 'out'
    //     endcase
    // end

    // GOOD: Complete case with default
    logic [7:0] mux_result;
    always_comb begin
        unique case (sel[1:0])
            2'b00:   mux_result = a;
            2'b01:   mux_result = b;
            2'b10:   mux_result = c;
            2'b11:   mux_result = d;
            default: mux_result = '0;
        endcase
    end

    // =========================================================================
    // 2. BLOCKING vs NON-BLOCKING
    // =========================================================================

    // BAD: Blocking assignment in sequential logic — causes simulation/synthesis mismatch
    // always_ff @(posedge clk) begin
    //     q1 = d;      // BAD: blocking in always_ff
    //     q2 = q1;     // races with above line
    // end

    // GOOD: Non-blocking in always_ff
    logic [7:0] q1, q2;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            q1 <= '0;
            q2 <= '0;
        end else begin
            q1 <= a;     // both update simultaneously
            q2 <= q1;    // creates a 2-stage pipeline
        end
    end

    // =========================================================================
    // 3. CLOCK ENABLE — don't gate the clock
    // =========================================================================

    // BAD: Gated clock
    // logic gated_clk;
    // assign gated_clk = clk & enable;
    // always_ff @(posedge gated_clk) q <= d;

    // GOOD: Clock enable
    logic [7:0] ce_reg;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            ce_reg <= '0;
        else if (enable)
            ce_reg <= a;
    end

    // =========================================================================
    // 4. REGISTERED OUTPUTS
    // =========================================================================

    // GOOD: Output registered for predictable timing
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            out_good <= '0;
        else
            out_good <= mux_result;
    end

    // =========================================================================
    // 5. MULTI-BIT SIGNALS ACROSS CLOCK DOMAINS
    // =========================================================================

    // BAD: Passing binary counter across domains
    // logic [3:0] counter_bin;
    // always_ff @(posedge clk_a) counter_bin <= counter_bin + 1;
    // always_ff @(posedge clk_b) sampled <= counter_bin;  // WRONG

    // GOOD: Convert to Gray code first, then synchronize
    // (see 09_clock_domain_crossing/ for full implementation)

    // =========================================================================
    // 6. RESET ALL CONTROL SIGNALS
    // =========================================================================

    // BAD: Unreset control flop can cause X-propagation
    // logic valid_unreset;
    // always_ff @(posedge clk)
    //     valid_unreset <= some_condition;  // no reset!

    // GOOD: All control signals have reset
    logic valid_good;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            valid_good <= 1'b0;
        else
            valid_good <= enable & mode;
    end

    // =========================================================================
    // 7. USE $clog2 FOR ADDRESS WIDTHS
    // =========================================================================

    // BAD: Hardcoded width
    // parameter DEPTH = 1024;
    // logic [9:0] addr;  // magic number 10

    // GOOD: Derived width
    localparam int DEPTH  = 1024;
    localparam int ADDR_W = $clog2(DEPTH);
    logic [ADDR_W-1:0] addr_example;

    // =========================================================================
    // 8. NAME GENERATE BLOCKS
    // =========================================================================

    // BAD: Unnamed generate
    // generate
    //     for (genvar i = 0; i < 4; i++) begin
    //         ...
    //     end
    // endgenerate

    // GOOD: Named generate (better hierarchy names in synthesis reports)
    logic [7:0] pipe [0:3];
    generate
        for (genvar i = 0; i < 4; i++) begin : gen_pipe_stage
            if (i == 0) begin : gen_first
                always_ff @(posedge clk or negedge rst_n)
                    if (!rst_n) pipe[0] <= '0;
                    else        pipe[0] <= a;
            end else begin : gen_rest
                always_ff @(posedge clk or negedge rst_n)
                    if (!rst_n) pipe[i] <= '0;
                    else        pipe[i] <= pipe[i-1];
            end
        end
    endgenerate

    assign out_example = pipe[3];

    assign addr_example = '0; // prevent unused warning

endmodule
