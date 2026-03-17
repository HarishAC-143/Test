// Traffic Light Controller - Moore FSM
// Models a simple intersection with main road and side road

module traffic_light_controller (
    input  logic       clk,
    input  logic       rst_n,
    input  logic       sensor_side,    // Vehicle detected on side road
    output logic [2:0] main_light,     // {Red, Yellow, Green}
    output logic [2:0] side_light      // {Red, Yellow, Green}
);

    typedef enum logic [2:0] {
        MAIN_GREEN   = 3'b000,
        MAIN_YELLOW  = 3'b001,
        SIDE_GREEN   = 3'b010,
        SIDE_YELLOW  = 3'b011,
        ALL_RED      = 3'b100
    } state_e;

    state_e state, next_state;

    localparam MAIN_GREEN_TIME  = 20;
    localparam YELLOW_TIME      = 5;
    localparam SIDE_GREEN_TIME  = 10;
    localparam ALL_RED_TIME     = 2;

    logic [4:0] timer;
    logic       timer_done;

    // State register
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= MAIN_GREEN;
        else
            state <= next_state;
    end

    // Timer
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            timer <= '0;
        else if (state != next_state)
            timer <= '0;
        else
            timer <= timer + 1'b1;
    end

    // Next-state logic
    always_comb begin
        next_state = state;
        timer_done = 1'b0;

        case (state)
            MAIN_GREEN: begin
                timer_done = (timer >= MAIN_GREEN_TIME - 1);
                if (timer_done && sensor_side)
                    next_state = MAIN_YELLOW;
            end

            MAIN_YELLOW: begin
                timer_done = (timer >= YELLOW_TIME - 1);
                if (timer_done)
                    next_state = ALL_RED;
            end

            ALL_RED: begin
                timer_done = (timer >= ALL_RED_TIME - 1);
                if (timer_done) begin
                    if (state == ALL_RED && side_light == 3'b100)
                        next_state = SIDE_GREEN;
                    else
                        next_state = MAIN_GREEN;
                end
            end

            SIDE_GREEN: begin
                timer_done = (timer >= SIDE_GREEN_TIME - 1);
                if (timer_done)
                    next_state = SIDE_YELLOW;
            end

            SIDE_YELLOW: begin
                timer_done = (timer >= YELLOW_TIME - 1);
                if (timer_done)
                    next_state = MAIN_GREEN;
            end

            default: next_state = MAIN_GREEN;
        endcase
    end

    // Output logic (Moore: depends only on state)
    always_comb begin
        case (state)
            MAIN_GREEN:  begin main_light = 3'b001; side_light = 3'b100; end
            MAIN_YELLOW: begin main_light = 3'b010; side_light = 3'b100; end
            SIDE_GREEN:  begin main_light = 3'b100; side_light = 3'b001; end
            SIDE_YELLOW: begin main_light = 3'b100; side_light = 3'b010; end
            ALL_RED:     begin main_light = 3'b100; side_light = 3'b100; end
            default:     begin main_light = 3'b100; side_light = 3'b100; end
        endcase
    end

endmodule
