// =============================================================================
// Traffic Light Controller — Two-Way Intersection
// Uses a timer-based FSM with configurable phase durations.
// Includes pedestrian crossing request support.
// =============================================================================

module traffic_light_controller #(
    parameter CLK_FREQ       = 50_000_000,  // 50 MHz
    parameter GREEN_TICKS    = CLK_FREQ * 10,  // 10 seconds
    parameter YELLOW_TICKS   = CLK_FREQ * 3,   // 3 seconds
    parameter RED_TICKS      = CLK_FREQ * 1,   // 1 second all-red overlap
    parameter PED_TICKS      = CLK_FREQ * 7,   // 7 seconds for pedestrian
    parameter TIMER_WIDTH    = $clog2(GREEN_TICKS + 1)
) (
    input  logic       clk,
    input  logic       rst_n,
    input  logic       ped_request,     // Pedestrian crossing request
    input  logic       emergency,       // Emergency override — all red
    output logic [2:0] light_ns,        // {Red, Yellow, Green} North-South
    output logic [2:0] light_ew,        // {Red, Yellow, Green} East-West
    output logic       ped_walk,        // Pedestrian walk signal
    output logic       ped_wait         // Pedestrian wait signal
);

    typedef enum logic [3:0] {
        NS_GREEN    = 4'b0001,
        NS_YELLOW   = 4'b0010,
        ALL_RED_1   = 4'b0011,
        EW_GREEN    = 4'b0100,
        EW_YELLOW   = 4'b0101,
        ALL_RED_2   = 4'b0110,
        PED_PHASE   = 4'b0111,
        EMERGENCY   = 4'b1000
    } state_e;

    state_e state, next_state;
    logic [TIMER_WIDTH-1:0] timer;
    logic timer_done;
    logic ped_pending;

    // Timer
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            timer <= '0;
        else if (state != next_state)
            timer <= '0;
        else
            timer <= timer + 1'b1;
    end

    // Latch pedestrian request until serviced
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            ped_pending <= 1'b0;
        else if (ped_request)
            ped_pending <= 1'b1;
        else if (state == PED_PHASE)
            ped_pending <= 1'b0;
    end

    // State register
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= NS_GREEN;
        else
            state <= next_state;
    end

    // Next state logic
    always_comb begin
        next_state = state;

        if (emergency) begin
            next_state = EMERGENCY;
        end else begin
            case (state)
                NS_GREEN:  if (timer >= GREEN_TICKS[TIMER_WIDTH-1:0] - 1)
                               next_state = NS_YELLOW;
                NS_YELLOW: if (timer >= YELLOW_TICKS[TIMER_WIDTH-1:0] - 1)
                               next_state = ALL_RED_1;
                ALL_RED_1: if (timer >= RED_TICKS[TIMER_WIDTH-1:0] - 1)
                               next_state = ped_pending ? PED_PHASE : EW_GREEN;
                EW_GREEN:  if (timer >= GREEN_TICKS[TIMER_WIDTH-1:0] - 1)
                               next_state = EW_YELLOW;
                EW_YELLOW: if (timer >= YELLOW_TICKS[TIMER_WIDTH-1:0] - 1)
                               next_state = ALL_RED_2;
                ALL_RED_2: if (timer >= RED_TICKS[TIMER_WIDTH-1:0] - 1)
                               next_state = NS_GREEN;
                PED_PHASE: if (timer >= PED_TICKS[TIMER_WIDTH-1:0] - 1)
                               next_state = EW_GREEN;
                EMERGENCY: if (!emergency)
                               next_state = ALL_RED_1;
                default:   next_state = NS_GREEN;
            endcase
        end
    end

    // Output logic
    always_comb begin
        // Defaults
        light_ns = 3'b100;  // Red
        light_ew = 3'b100;  // Red
        ped_walk = 1'b0;
        ped_wait = 1'b1;

        case (state)
            NS_GREEN:  begin light_ns = 3'b001; light_ew = 3'b100; end
            NS_YELLOW: begin light_ns = 3'b010; light_ew = 3'b100; end
            ALL_RED_1: begin light_ns = 3'b100; light_ew = 3'b100; end
            EW_GREEN:  begin light_ns = 3'b100; light_ew = 3'b001; end
            EW_YELLOW: begin light_ns = 3'b100; light_ew = 3'b010; end
            ALL_RED_2: begin light_ns = 3'b100; light_ew = 3'b100; end
            PED_PHASE: begin
                light_ns = 3'b100;
                light_ew = 3'b100;
                ped_walk = 1'b1;
                ped_wait = 1'b0;
            end
            EMERGENCY: begin
                light_ns = 3'b100;
                light_ew = 3'b100;
            end
            default: begin
                light_ns = 3'b100;
                light_ew = 3'b100;
            end
        endcase
    end

endmodule
