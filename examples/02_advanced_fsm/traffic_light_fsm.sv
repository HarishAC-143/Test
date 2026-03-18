// ----------------------------------------------------------------------------
// Advanced FSM: Configurable Traffic Light Controller
// Demonstrates: typedef enum, struct outputs, timer-based transitions,
//               emergency override, pedestrian crossing request
// ----------------------------------------------------------------------------

module traffic_light_controller #(
    parameter int CLK_FREQ_HZ  = 50_000_000,
    parameter int GREEN_SEC    = 30,
    parameter int YELLOW_SEC   = 5,
    parameter int RED_SEC      = 2,
    parameter int PED_WALK_SEC = 15
)(
    input  logic clk,
    input  logic rst_n,
    input  logic sensor_ns,       // Vehicle sensor north-south
    input  logic sensor_ew,       // Vehicle sensor east-west
    input  logic ped_request,     // Pedestrian crossing button
    input  logic emergency,       // Emergency vehicle override

    output light_state_t light_ns,
    output light_state_t light_ew,
    output logic         ped_walk,
    output logic         ped_countdown
);

    typedef struct packed {
        logic red;
        logic yellow;
        logic green;
    } light_state_t;

    typedef enum logic [3:0] {
        ST_NS_GREEN      = 4'd0,
        ST_NS_YELLOW     = 4'd1,
        ST_ALL_RED_1     = 4'd2,
        ST_EW_GREEN      = 4'd3,
        ST_EW_YELLOW     = 4'd4,
        ST_ALL_RED_2     = 4'd5,
        ST_PED_WALK      = 4'd6,
        ST_PED_CLEAR     = 4'd7,
        ST_EMERGENCY     = 4'd8
    } traffic_state_t;

    traffic_state_t state, next_state;

    localparam int TIMER_WIDTH = $clog2(CLK_FREQ_HZ * GREEN_SEC + 1);

    logic [TIMER_WIDTH-1:0] timer;
    logic                   timer_expired;
    logic [TIMER_WIDTH-1:0] timer_load_val;
    logic                   timer_load;
    logic                   ped_request_latched;

    // Timer counts down to zero
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            timer <= '0;
        else if (timer_load)
            timer <= timer_load_val;
        else if (timer > 0)
            timer <= timer - 1'b1;
    end

    assign timer_expired = (timer == '0);

    // Latch pedestrian request until served
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            ped_request_latched <= 1'b0;
        else if (state == ST_PED_WALK)
            ped_request_latched <= 1'b0;
        else if (ped_request)
            ped_request_latched <= 1'b1;
    end

    // Next-state logic
    always_comb begin
        next_state     = state;
        timer_load     = 1'b0;
        timer_load_val = '0;

        if (emergency && state != ST_EMERGENCY) begin
            next_state     = ST_EMERGENCY;
            timer_load     = 1'b1;
            timer_load_val = '0;
        end else begin
            case (state)
                ST_NS_GREEN: begin
                    if (timer_expired) begin
                        next_state     = ST_NS_YELLOW;
                        timer_load     = 1'b1;
                        timer_load_val = YELLOW_SEC * CLK_FREQ_HZ;
                    end
                end

                ST_NS_YELLOW: begin
                    if (timer_expired) begin
                        next_state     = ST_ALL_RED_1;
                        timer_load     = 1'b1;
                        timer_load_val = RED_SEC * CLK_FREQ_HZ;
                    end
                end

                ST_ALL_RED_1: begin
                    if (timer_expired) begin
                        if (ped_request_latched) begin
                            next_state     = ST_PED_WALK;
                            timer_load     = 1'b1;
                            timer_load_val = PED_WALK_SEC * CLK_FREQ_HZ;
                        end else begin
                            next_state     = ST_EW_GREEN;
                            timer_load     = 1'b1;
                            timer_load_val = GREEN_SEC * CLK_FREQ_HZ;
                        end
                    end
                end

                ST_EW_GREEN: begin
                    if (timer_expired) begin
                        next_state     = ST_EW_YELLOW;
                        timer_load     = 1'b1;
                        timer_load_val = YELLOW_SEC * CLK_FREQ_HZ;
                    end
                end

                ST_EW_YELLOW: begin
                    if (timer_expired) begin
                        next_state     = ST_ALL_RED_2;
                        timer_load     = 1'b1;
                        timer_load_val = RED_SEC * CLK_FREQ_HZ;
                    end
                end

                ST_ALL_RED_2: begin
                    if (timer_expired) begin
                        next_state     = ST_NS_GREEN;
                        timer_load     = 1'b1;
                        timer_load_val = GREEN_SEC * CLK_FREQ_HZ;
                    end
                end

                ST_PED_WALK: begin
                    if (timer_expired) begin
                        next_state     = ST_PED_CLEAR;
                        timer_load     = 1'b1;
                        timer_load_val = 5 * CLK_FREQ_HZ;
                    end
                end

                ST_PED_CLEAR: begin
                    if (timer_expired) begin
                        next_state     = ST_EW_GREEN;
                        timer_load     = 1'b1;
                        timer_load_val = GREEN_SEC * CLK_FREQ_HZ;
                    end
                end

                ST_EMERGENCY: begin
                    if (!emergency) begin
                        next_state     = ST_ALL_RED_2;
                        timer_load     = 1'b1;
                        timer_load_val = RED_SEC * CLK_FREQ_HZ;
                    end
                end

                default: begin
                    next_state     = ST_NS_GREEN;
                    timer_load     = 1'b1;
                    timer_load_val = GREEN_SEC * CLK_FREQ_HZ;
                end
            endcase
        end
    end

    // State register
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= ST_NS_GREEN;
        else
            state <= next_state;
    end

    // Output decode (Moore-style)
    always_comb begin
        light_ns      = '{red: 1'b1, yellow: 1'b0, green: 1'b0};
        light_ew      = '{red: 1'b1, yellow: 1'b0, green: 1'b0};
        ped_walk      = 1'b0;
        ped_countdown = 1'b0;

        case (state)
            ST_NS_GREEN:  light_ns = '{red: 1'b0, yellow: 1'b0, green: 1'b1};
            ST_NS_YELLOW: light_ns = '{red: 1'b0, yellow: 1'b1, green: 1'b0};
            ST_EW_GREEN:  light_ew = '{red: 1'b0, yellow: 1'b0, green: 1'b1};
            ST_EW_YELLOW: light_ew = '{red: 1'b0, yellow: 1'b1, green: 1'b0};
            ST_PED_WALK:  ped_walk = 1'b1;
            ST_PED_CLEAR: ped_countdown = 1'b1;
            ST_EMERGENCY: begin
                // All red during emergency
                light_ns = '{red: 1'b1, yellow: 1'b0, green: 1'b0};
                light_ew = '{red: 1'b1, yellow: 1'b0, green: 1'b0};
            end
            default: ;
        endcase
    end

endmodule
