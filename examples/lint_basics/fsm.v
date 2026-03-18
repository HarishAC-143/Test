//-----------------------------------------------------------------------------
// Example: Finite State Machine Lint Issues
//
// SpyGlass Rules Triggered:
//   W_116          - Latch inferred (incomplete case)
//   STARC-2.1.4.4  - Case statement missing default
//   W_146          - Unreachable state detected
//   W_392          - FSM output not registered
//
// Demonstrates common FSM design mistakes that SpyGlass catches.
//-----------------------------------------------------------------------------

module fsm_bad (
    input  wire clk,
    input  wire rst_n,
    input  wire start,
    input  wire done,
    output reg  busy,
    output reg  error,
    output reg  ack
);

    // State encoding
    localparam [2:0] IDLE  = 3'b000,
                     INIT  = 3'b001,
                     RUN   = 3'b010,
                     WAIT  = 3'b011,
                     DONE  = 3'b100,
                     DEAD  = 3'b101;  // Unreachable state — W_146

    reg [2:0] state, next_state;

    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= IDLE;
        else
            state <= next_state;
    end

    // BUG: No default case → latch for next_state (W_116)
    // BUG: DEAD state is unreachable — no transition leads to it (W_146)
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = INIT;
                else
                    next_state = IDLE;
            end
            INIT:
                next_state = RUN;
            RUN: begin
                if (done)
                    next_state = DONE;
                // BUG: Missing else — when done=0, next_state is latched
            end
            WAIT:
                next_state = RUN;
            DONE:
                next_state = IDLE;
            // Missing: default case
            // Missing: DEAD state (never transitions here anyway)
        endcase
    end

    // BUG: Combinational outputs from FSM — glitch-prone (W_392)
    always @(*) begin
        busy  = 1'b0;
        error = 1'b0;
        ack   = 1'b0;
        case (state)
            RUN:   busy = 1'b1;
            DONE:  ack  = 1'b1;
            DEAD:  error = 1'b1;
        endcase
    end

endmodule


module fsm_good (
    input  wire clk,
    input  wire rst_n,
    input  wire start,
    input  wire done,
    output reg  busy,
    output reg  error,
    output reg  ack
);

    localparam [1:0] IDLE = 2'b00,
                     INIT = 2'b01,
                     RUN  = 2'b10,
                     DONE = 2'b11;

    reg [1:0] state, next_state;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= IDLE;
        else
            state <= next_state;
    end

    // FIX: Complete case with default, all branches assign next_state
    always @(*) begin
        next_state = state;  // Default: hold state (prevents latches)
        case (state)
            IDLE:
                if (start) next_state = INIT;
            INIT:
                next_state = RUN;
            RUN:
                if (done) next_state = DONE;
            DONE:
                next_state = IDLE;
            default:
                next_state = IDLE;  // Safe recovery
        endcase
    end

    // FIX: Registered outputs — glitch-free
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            busy  <= 1'b0;
            error <= 1'b0;
            ack   <= 1'b0;
        end else begin
            busy  <= (next_state == RUN);
            error <= 1'b0;
            ack   <= (next_state == DONE);
        end
    end

endmodule
