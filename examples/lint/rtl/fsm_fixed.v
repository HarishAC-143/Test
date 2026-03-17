// =============================================================================
// FSM — Fixed Version (All Lint Issues Resolved)
// =============================================================================
// A traffic light controller FSM with all lint violations corrected.
// =============================================================================

module fsm_fixed (
    input  wire clk,
    input  wire rst_n,
    input  wire sensor,
    input  wire emergency,
    output reg  red,
    output reg  yellow,
    output reg  green
);

    // Fix 1: Use localparam for state encoding (no magic numbers)
    localparam [1:0] ST_GREEN  = 2'd0,
                     ST_YELLOW = 2'd1,
                     ST_RED    = 2'd2,
                     ST_EMERG  = 2'd3;

    reg [1:0] state, next_state;

    // Fix 3, 4, 5: Blocking assignments, default case, reachable states
    always @(*) begin
        next_state = state;  // Default: hold current state (prevents latch)

        case (state)
            ST_GREEN: begin
                if (emergency)
                    next_state = ST_EMERG;
                else if (sensor)
                    next_state = ST_YELLOW;
            end

            ST_YELLOW:
                next_state = ST_RED;

            ST_RED: begin
                if (emergency)
                    next_state = ST_EMERG;
                else if (!sensor)
                    next_state = ST_GREEN;
            end

            ST_EMERG: begin
                if (!emergency)
                    next_state = ST_RED;  // Fix: exit path from emergency
            end

            default:
                next_state = ST_GREEN;    // Fix: explicit default
        endcase
    end

    // Fix 6: Non-blocking assignments in sequential block
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= ST_GREEN;
        else
            state <= next_state;
    end

    // Fix 7: All outputs assigned in all branches, with default
    always @(*) begin
        red    = 1'b0;
        yellow = 1'b0;
        green  = 1'b0;

        case (state)
            ST_GREEN:  green  = 1'b1;
            ST_YELLOW: yellow = 1'b1;
            ST_RED:    red    = 1'b1;
            ST_EMERG: begin
                red    = 1'b1;
                yellow = 1'b1;  // Flash red + yellow for emergency
            end
            default: begin
                red    = 1'b1;  // Safe default
            end
        endcase
    end

endmodule
