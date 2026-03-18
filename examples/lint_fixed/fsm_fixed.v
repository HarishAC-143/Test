// =============================================================================
// Example 3 — FIXED: FSM with All Lint Issues Resolved
// =============================================================================
// Compare with: examples/lint_issues/fsm_issues.v
//
// All issues addressed:
//   [FIXED] FSM_NO_DEFAULT  — Added default case with recovery to IDLE
//   [FIXED] FSM_DEADEND     — ERROR state now transitions out on !error
//   [FIXED] FSM_UNREACHABLE — Removed unused UNUSED state
//   [FIXED] W_LATCH         — All outputs assigned default values
//   [FIXED] W_REGS_ARST     — State register has async reset
// =============================================================================

module fsm_fixed (
    input  wire clk,
    input  wire rst_n,
    input  wire start,
    input  wire done,
    input  wire error,
    output reg  busy,
    output reg  ack,
    output reg  err_flag
);

    // FIX: Removed UNUSED state — it was unreachable dead code.
    localparam [2:0] IDLE    = 3'b000,
                     INIT    = 3'b001,
                     PROCESS = 3'b010,
                     FINISH  = 3'b011,
                     ERROR   = 3'b100;

    reg [2:0] state, next_state;

    // FIX 1: Added asynchronous reset to state register.
    // FSM now starts in IDLE at power-up — deterministic initial state.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= IDLE;
        else
            state <= next_state;
    end

    // FIX 2: Added default case for recovery.
    // FIX 3: ERROR state now transitions to IDLE when error is deasserted.
    always @(*) begin
        next_state = state;
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
                if (!error)
                    next_state = IDLE;  // Recovery path added
            end

            default: begin
                next_state = IDLE;  // Safe recovery from undefined states
            end
        endcase
    end

    // FIX 5: All outputs have default values at the top of the block.
    // No latch inference — every output is assigned in every path.
    always @(*) begin
        busy     = 1'b0;
        ack      = 1'b0;
        err_flag = 1'b0;  // Default value prevents latch

        case (state)
            IDLE: begin
                // All outputs use defaults (0)
            end

            INIT: begin
                busy = 1'b1;
            end

            PROCESS: begin
                busy = 1'b1;
            end

            FINISH: begin
                ack = 1'b1;
            end

            ERROR: begin
                err_flag = 1'b1;
            end

            default: begin
                // All outputs use defaults (0)
            end
        endcase
    end

endmodule
