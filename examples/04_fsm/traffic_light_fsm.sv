// ============================================================================
// Traffic Light FSM — Two-Process Style
// ============================================================================
// Demonstrates the recommended two-process FSM coding style:
//   1. Sequential process: state register update
//   2. Combinational process: next-state and output logic
//
// This approach keeps state transitions explicit and avoids accidental
// latch inference. The `unique case` keyword asserts mutual exclusivity,
// enabling the synthesis tool to optimize and the simulator to flag errors.
// ============================================================================

module traffic_light_fsm (
    input  logic clk,
    input  logic rst_n,
    input  logic sensor,      // pedestrian / vehicle sensor
    output logic red,
    output logic yellow,
    output logic green
);

    typedef enum logic [1:0] {
        S_RED    = 2'b00,
        S_GREEN  = 2'b01,
        S_YELLOW = 2'b10
    } state_t;

    state_t state, next_state;
    logic [3:0] timer, next_timer;

    // Sequential process — state register
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_RED;
            timer <= '0;
        end else begin
            state <= next_state;
            timer <= next_timer;
        end
    end

    // Combinational process — next-state and output decode
    always_comb begin
        next_state = state;
        next_timer = timer + 4'd1;
        {red, yellow, green} = 3'b000;

        unique case (state)
            S_RED: begin
                red = 1'b1;
                if (timer == 4'd9 && sensor) begin
                    next_state = S_GREEN;
                    next_timer = '0;
                end
            end

            S_GREEN: begin
                green = 1'b1;
                if (timer == 4'd7) begin
                    next_state = S_YELLOW;
                    next_timer = '0;
                end
            end

            S_YELLOW: begin
                yellow = 1'b1;
                if (timer == 4'd2) begin
                    next_state = S_RED;
                    next_timer = '0;
                end
            end

            default: begin
                next_state = S_RED;
                next_timer = '0;
                red = 1'b1;
            end
        endcase
    end

endmodule
