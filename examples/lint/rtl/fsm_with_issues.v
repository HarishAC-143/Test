// =============================================================================
// FSM with Lint Issues
// =============================================================================
// A traffic light controller FSM with multiple lint violations.
// Compare with fsm_fixed.v for the corrected version.
// =============================================================================

module fsm_with_issues (
    input  wire clk,
    input  wire rst_n,
    input  wire sensor,       // Car sensor on side road
    input  wire emergency,    // Emergency vehicle detected
    output reg  red,
    output reg  yellow,
    output reg  green
);

    // -------------------------------------------------------------------------
    // Issue 1: Using magic numbers instead of parameters/localparams
    // Issue 2: State encoding leaves unused states → W_0551 potential
    // -------------------------------------------------------------------------
    reg [2:0] state;
    reg [2:0] next_state;

    // -------------------------------------------------------------------------
    // Issue 3: W_0408 — Inferred latch (incomplete case in combinational block)
    // Issue 4: W_0527 — Non-blocking in combinational block
    // Issue 5: W_0551 — Unreachable states (states 4, 5, 6, 7 never used)
    // -------------------------------------------------------------------------
    always @(*) begin
        case (state)
            3'd0: begin  // GREEN
                if (sensor || emergency)
                    next_state <= 3'd1;   // BAD: non-blocking in combo
                else
                    next_state <= 3'd0;   // BAD: non-blocking in combo
            end
            3'd1: begin  // YELLOW
                next_state <= 3'd2;       // BAD: non-blocking in combo
            end
            3'd2: begin  // RED
                if (!sensor && !emergency)
                    next_state <= 3'd0;   // BAD: non-blocking in combo
                else
                    next_state <= 3'd2;   // BAD: non-blocking in combo
            end
            3'd3: begin  // EMERGENCY — reachable but dead-end (W_0552)
                next_state <= 3'd3;       // Stays here forever!
            end
            // Missing default! States 4-7 will infer latches (W_0408)
        endcase
    end

    // -------------------------------------------------------------------------
    // Issue 6: W_0528 — Blocking assignment in sequential block
    // -------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state = 3'd0;     // BAD: blocking in sequential
        else
            state = next_state; // BAD: blocking in sequential
    end

    // -------------------------------------------------------------------------
    // Issue 7: W_0408 — Latch inferred for outputs (missing else / default)
    // -------------------------------------------------------------------------
    always @(*) begin
        case (state)
            3'd0: begin
                green  = 1'b1;
                yellow = 1'b0;
                red    = 1'b0;
            end
            3'd1: begin
                green  = 1'b0;
                yellow = 1'b1;
                // red not assigned — latch inferred!
            end
            3'd2: begin
                green  = 1'b0;
                // yellow not assigned — latch inferred!
                red    = 1'b1;
            end
            // No default — latches for all outputs on states 3-7!
        endcase
    end

endmodule
