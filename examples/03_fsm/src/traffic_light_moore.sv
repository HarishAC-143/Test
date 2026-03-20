// Traffic Light Controller — Moore FSM
// Implements a simple traffic light with red, yellow, and green phases.
// Each phase runs for a configurable number of clock cycles.
// Moore machine: outputs depend only on the current state.

module traffic_light_moore #(
    parameter GREEN_TICKS  = 100,
    parameter YELLOW_TICKS = 30,
    parameter RED_TICKS    = 120,
    parameter CNT_WIDTH    = $clog2(RED_TICKS + 1)
)(
    input  logic clk,
    input  logic rst_n,
    input  logic sensor,    // car detected on cross street (shortens green)
    output logic red,
    output logic yellow,
    output logic green
);

    typedef enum logic [1:0] {
        S_GREEN  = 2'b00,
        S_YELLOW = 2'b01,
        S_RED    = 2'b10
    } state_t;

    state_t state, next_state;
    logic [CNT_WIDTH-1:0] timer, next_timer;

    // State register
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_RED;
            timer <= '0;
        end else begin
            state <= next_state;
            timer <= next_timer;
        end
    end

    // Next-state and timer logic
    always_comb begin
        next_state = state;
        next_timer = timer + 1'b1;

        case (state)
            S_GREEN: begin
                if ((timer >= GREEN_TICKS[CNT_WIDTH-1:0] - 1) ||
                    (sensor && timer >= (GREEN_TICKS[CNT_WIDTH-1:0] >> 1))) begin
                    next_state = S_YELLOW;
                    next_timer = '0;
                end
            end

            S_YELLOW: begin
                if (timer >= YELLOW_TICKS[CNT_WIDTH-1:0] - 1) begin
                    next_state = S_RED;
                    next_timer = '0;
                end
            end

            S_RED: begin
                if (timer >= RED_TICKS[CNT_WIDTH-1:0] - 1) begin
                    next_state = S_GREEN;
                    next_timer = '0;
                end
            end

            default: begin
                next_state = S_RED;
                next_timer = '0;
            end
        endcase
    end

    // Moore outputs: depend only on state
    assign green  = (state == S_GREEN);
    assign yellow = (state == S_YELLOW);
    assign red    = (state == S_RED);

endmodule
