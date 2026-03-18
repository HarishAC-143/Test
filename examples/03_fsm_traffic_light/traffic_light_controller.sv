// Advanced FSM: Traffic Light Controller
// Controls a 4-way intersection with main road, side road,
// pedestrian crossing, and emergency vehicle override.
// Uses the two-process FSM coding style (gold standard).

module traffic_light_controller #(
    parameter int CLK_FREQ_HZ    = 50_000_000,
    parameter int GREEN_TIME_MS  = 10_000,
    parameter int YELLOW_TIME_MS = 3_000,
    parameter int PED_TIME_MS    = 7_000,
    parameter int ALL_RED_MS     = 1_000
) (
    input  logic       clk,
    input  logic       rst_n,
    input  logic       sensor_side_road,   // Vehicle detected on side road
    input  logic       ped_request,        // Pedestrian button pressed
    input  logic       emergency,          // Emergency vehicle override

    output logic [2:0] main_light,         // {green, yellow, red}
    output logic [2:0] side_light,         // {green, yellow, red}
    output logic [1:0] ped_light,          // {walk, dont_walk}
    output logic       ped_buzzer          // Audible signal for pedestrians
);

    // Timer tick generation: 1 ms tick
    localparam int TICK_COUNT = CLK_FREQ_HZ / 1000;
    localparam int TICK_W     = $clog2(TICK_COUNT + 1);

    logic [TICK_W-1:0] tick_counter;
    logic              ms_tick;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tick_counter <= '0;
        end else if (tick_counter >= TICK_COUNT - 1) begin
            tick_counter <= '0;
        end else begin
            tick_counter <= tick_counter + 1;
        end
    end

    assign ms_tick = (tick_counter == TICK_COUNT - 1);

    // State machine timer
    localparam int MAX_TIME = GREEN_TIME_MS;
    localparam int TIMER_W  = $clog2(MAX_TIME + 1);

    logic [TIMER_W-1:0] timer;
    logic               timer_done;
    logic [TIMER_W-1:0] timer_limit;
    logic               timer_start;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            timer <= '0;
        end else if (timer_start) begin
            timer <= '0;
        end else if (ms_tick && !timer_done) begin
            timer <= timer + 1;
        end
    end

    assign timer_done = (timer >= timer_limit);

    // Pedestrian request latch: hold request until serviced
    logic ped_req_latched;
    logic ped_req_clear;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            ped_req_latched <= 1'b0;
        else if (ped_req_clear)
            ped_req_latched <= 1'b0;
        else if (ped_request)
            ped_req_latched <= 1'b1;
    end

    // FSM states
    typedef enum logic [3:0] {
        S_MAIN_GREEN,
        S_MAIN_YELLOW,
        S_ALL_RED_1,
        S_SIDE_GREEN,
        S_SIDE_YELLOW,
        S_ALL_RED_2,
        S_PED_WALK,
        S_PED_FLASH,
        S_ALL_RED_3,
        S_EMERGENCY
    } state_t;

    state_t state, next_state;

    // Flashing counter for pedestrian "don't walk" flash
    logic [3:0] flash_counter;
    logic       flash_tick;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            flash_counter <= '0;
        else if (state == S_PED_FLASH && ms_tick)
            flash_counter <= flash_counter + 1;
        else if (state != S_PED_FLASH)
            flash_counter <= '0;
    end

    assign flash_tick = flash_counter[2]; // Toggle every ~4 ms ticks

    // --- Sequential block: state register ---
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= S_MAIN_GREEN;
        else
            state <= next_state;
    end

    // --- Combinational block: next-state + output logic ---
    always_comb begin
        next_state    = state;
        timer_limit   = '0;
        timer_start   = 1'b0;
        ped_req_clear = 1'b0;

        main_light = 3'b001;  // Default: red
        side_light = 3'b001;  // Default: red
        ped_light  = 2'b01;   // Default: don't walk
        ped_buzzer = 1'b0;

        // Emergency override takes priority
        if (emergency && state != S_EMERGENCY) begin
            next_state  = S_EMERGENCY;
            timer_start = 1'b1;
        end else begin
            unique case (state)
                S_MAIN_GREEN: begin
                    main_light  = 3'b100;  // Green
                    timer_limit = GREEN_TIME_MS;
                    if (timer_done && (sensor_side_road || ped_req_latched)) begin
                        next_state  = S_MAIN_YELLOW;
                        timer_start = 1'b1;
                    end
                end

                S_MAIN_YELLOW: begin
                    main_light  = 3'b010;  // Yellow
                    timer_limit = YELLOW_TIME_MS;
                    if (timer_done) begin
                        next_state  = S_ALL_RED_1;
                        timer_start = 1'b1;
                    end
                end

                S_ALL_RED_1: begin
                    timer_limit = ALL_RED_MS;
                    if (timer_done) begin
                        if (ped_req_latched) begin
                            next_state  = S_PED_WALK;
                            timer_start = 1'b1;
                        end else begin
                            next_state  = S_SIDE_GREEN;
                            timer_start = 1'b1;
                        end
                    end
                end

                S_SIDE_GREEN: begin
                    side_light  = 3'b100;  // Green
                    timer_limit = GREEN_TIME_MS;
                    if (timer_done) begin
                        next_state  = S_SIDE_YELLOW;
                        timer_start = 1'b1;
                    end
                end

                S_SIDE_YELLOW: begin
                    side_light  = 3'b010;  // Yellow
                    timer_limit = YELLOW_TIME_MS;
                    if (timer_done) begin
                        next_state  = S_ALL_RED_2;
                        timer_start = 1'b1;
                    end
                end

                S_ALL_RED_2: begin
                    timer_limit = ALL_RED_MS;
                    if (timer_done) begin
                        next_state  = S_MAIN_GREEN;
                        timer_start = 1'b1;
                    end
                end

                S_PED_WALK: begin
                    ped_light   = 2'b10;   // Walk
                    ped_buzzer  = 1'b1;
                    timer_limit = PED_TIME_MS;
                    ped_req_clear = 1'b1;
                    if (timer_done) begin
                        next_state  = S_PED_FLASH;
                        timer_start = 1'b1;
                    end
                end

                S_PED_FLASH: begin
                    ped_light   = flash_tick ? 2'b01 : 2'b10;
                    timer_limit = YELLOW_TIME_MS;
                    if (timer_done) begin
                        next_state  = S_ALL_RED_3;
                        timer_start = 1'b1;
                    end
                end

                S_ALL_RED_3: begin
                    timer_limit = ALL_RED_MS;
                    if (timer_done) begin
                        if (sensor_side_road) begin
                            next_state  = S_SIDE_GREEN;
                            timer_start = 1'b1;
                        end else begin
                            next_state  = S_MAIN_GREEN;
                            timer_start = 1'b1;
                        end
                    end
                end

                S_EMERGENCY: begin
                    main_light = 3'b001;  // All red
                    side_light = 3'b001;
                    ped_light  = 2'b01;
                    if (!emergency) begin
                        next_state  = S_MAIN_GREEN;
                        timer_start = 1'b1;
                    end
                end

                default: begin
                    next_state  = S_MAIN_GREEN;
                    timer_start = 1'b1;
                end
            endcase
        end
    end

endmodule
