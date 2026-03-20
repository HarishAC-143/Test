// Moore FSM — Traffic light controller.
//
// States: RED -> GREEN -> YELLOW -> RED
// Each state lasts a configurable number of clock cycles.
// The sensor input can shorten the GREEN phase.

module traffic_light_fsm #(
    parameter int RED_TICKS    = 100,
    parameter int GREEN_TICKS  = 80,
    parameter int YELLOW_TICKS = 20
)(
    input  logic       clk,
    input  logic       rst_n,
    input  logic       sensor,     // car sensor — can shorten green
    output logic       red,
    output logic       yellow,
    output logic       green
);

    localparam int MAX_TICKS = RED_TICKS;   // largest timer value
    localparam int TIMER_W   = $clog2(MAX_TICKS + 1);

    typedef enum logic [1:0] {
        S_RED    = 2'b00,
        S_GREEN  = 2'b01,
        S_YELLOW = 2'b10
    } state_t;

    state_t state_q, state_d;
    logic [TIMER_W-1:0] timer_q, timer_d;

    // State register
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_q <= S_RED;
            timer_q <= '0;
        end else begin
            state_q <= state_d;
            timer_q <= timer_d;
        end
    end

    // Next-state and timer logic
    always_comb begin
        state_d = state_q;
        timer_d = timer_q + 1'b1;

        unique case (state_q)
            S_RED: begin
                if (timer_q == TIMER_W'(RED_TICKS - 1)) begin
                    state_d = S_GREEN;
                    timer_d = '0;
                end
            end

            S_GREEN: begin
                if (timer_q == TIMER_W'(GREEN_TICKS - 1) ||
                    (sensor && timer_q >= TIMER_W'(GREEN_TICKS / 2))) begin
                    state_d = S_YELLOW;
                    timer_d = '0;
                end
            end

            S_YELLOW: begin
                if (timer_q == TIMER_W'(YELLOW_TICKS - 1)) begin
                    state_d = S_RED;
                    timer_d = '0;
                end
            end

            default: begin
                state_d = S_RED;
                timer_d = '0;
            end
        endcase
    end

    // Moore outputs — depend only on state
    assign red    = (state_q == S_RED);
    assign green  = (state_q == S_GREEN);
    assign yellow = (state_q == S_YELLOW);

endmodule
