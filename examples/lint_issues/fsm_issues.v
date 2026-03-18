// =============================================================================
// Example 3: FSM with Lint Issues
// =============================================================================
// A state machine with several design problems that SpyGlass Lint catches:
//
//   FSM_NO_DEFAULT  — Missing default in state case
//   FSM_DEADEND     — Dead-end state (no exit transition)
//   FSM_UNREACHABLE — State that can never be entered
//   W_LATCH         — Output latch from incomplete assignment
//   W_REGS_ARST     — State register without async reset
// =============================================================================

module fsm_issues (
    input  wire clk,
    input  wire rst_n,
    input  wire start,
    input  wire done,
    input  wire error,
    output reg  busy,
    output reg  ack,
    output reg  err_flag
);

    // State encoding — one-hot would be cleaner but using binary here
    localparam [2:0] IDLE    = 3'b000,
                     INIT    = 3'b001,
                     PROCESS = 3'b010,
                     FINISH  = 3'b011,
                     ERROR   = 3'b100,
                     UNUSED  = 3'b101;  // ISSUE: unreachable state

    reg [2:0] state, next_state;

    // -------------------------------------------------------------------------
    // ISSUE 1: W_REGS_ARST — State register without async reset.
    // At power-up, 'state' is unknown. The FSM may start in an
    // undefined state, causing unpredictable behavior.
    // -------------------------------------------------------------------------
    always @(posedge clk) begin
        state <= next_state;
    end

    // -------------------------------------------------------------------------
    // ISSUE 2: FSM_NO_DEFAULT — No default case.
    // If the state register enters an undefined value (e.g., from a
    // cosmic ray bit-flip or power-up), the FSM has no recovery path.
    //
    // ISSUE 3: FSM_DEADEND — ERROR state has no exit transition.
    // Once the FSM enters ERROR, it is stuck forever.
    //
    // ISSUE 4: FSM_UNREACHABLE — UNUSED state is defined but no
    // transition leads to it. This is dead code.
    // -------------------------------------------------------------------------
    always @(*) begin
        next_state = state;  // default to hold state (avoids latch on next_state)
        case (state)
            IDLE: begin
                if (start)
                    next_state = INIT;
            end

            INIT: begin
                if (error)
                    next_state = ERROR;
                else
                    next_state = PROCESS;
            end

            PROCESS: begin
                if (done)
                    next_state = FINISH;
                else if (error)
                    next_state = ERROR;
            end

            FINISH: begin
                next_state = IDLE;
            end

            ERROR: begin
                // DEADEND: No transition out of ERROR state!
                // FSM is stuck here permanently.
                next_state = ERROR;
            end

            // MISSING: No case for UNUSED (3'b101) → it's unreachable anyway
            // MISSING: No default case → undefined states have no recovery
        endcase
    end

    // -------------------------------------------------------------------------
    // ISSUE 5: W_LATCH — Output 'err_flag' is not assigned in all branches.
    // In states where err_flag is not explicitly set, it retains its
    // value → latch inferred.
    //
    // Correct approach: Assign all outputs at the top of the always block
    // with default values, then override in specific states.
    // -------------------------------------------------------------------------
    always @(*) begin
        busy = 1'b0;
        ack  = 1'b0;
        // err_flag not assigned a default → latch!

        case (state)
            IDLE: begin
                busy = 1'b0;
                ack  = 1'b0;
            end

            INIT: begin
                busy = 1'b1;
            end

            PROCESS: begin
                busy = 1'b1;
            end

            FINISH: begin
                busy = 1'b0;
                ack  = 1'b1;
            end

            ERROR: begin
                busy     = 1'b0;
                err_flag = 1'b1;
            end
        endcase
    end

endmodule
