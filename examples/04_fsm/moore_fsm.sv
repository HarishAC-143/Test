// Moore Finite State Machine
// Traffic Light Controller: outputs depend only on current state
// Controls a simple intersection with North-South and East-West lights

module traffic_light_moore (
    input  logic       clk,
    input  logic       rst_n,
    input  logic       sensor_ns,    // Vehicle sensor North-South
    input  logic       sensor_ew,    // Vehicle sensor East-West
    output logic [2:0] light_ns,     // {Red, Yellow, Green} North-South
    output logic [2:0] light_ew      // {Red, Yellow, Green} East-West
);

    typedef enum logic [2:0] {
        NS_GREEN    = 3'b000,
        NS_YELLOW   = 3'b001,
        EW_GREEN    = 3'b010,
        EW_YELLOW   = 3'b011,
        ALL_RED     = 3'b100
    } state_e;

    state_e state_q, state_d;

    localparam int TIMER_WIDTH = 4;
    logic [TIMER_WIDTH-1:0] timer_q;
    logic                   timer_done;

    localparam logic [TIMER_WIDTH-1:0] GREEN_TIME  = 4'd10;
    localparam logic [TIMER_WIDTH-1:0] YELLOW_TIME = 4'd3;
    localparam logic [TIMER_WIDTH-1:0] RED_TIME    = 4'd1;

    // State register
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state_q <= NS_GREEN;
        else
            state_q <= state_d;
    end

    // Timer
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            timer_q <= '0;
        else if (state_q != state_d)
            timer_q <= '0;
        else
            timer_q <= timer_q + 1'b1;
    end

    // Next state logic
    always_comb begin
        state_d = state_q;
        unique case (state_q)
            NS_GREEN: begin
                if (timer_q >= GREEN_TIME && sensor_ew)
                    state_d = NS_YELLOW;
            end
            NS_YELLOW: begin
                if (timer_q >= YELLOW_TIME)
                    state_d = ALL_RED;
            end
            ALL_RED: begin
                if (timer_q >= RED_TIME) begin
                    if (state_q == ALL_RED && light_ns[2])
                        state_d = EW_GREEN;
                    else
                        state_d = NS_GREEN;
                end
            end
            EW_GREEN: begin
                if (timer_q >= GREEN_TIME && sensor_ns)
                    state_d = EW_YELLOW;
            end
            EW_YELLOW: begin
                if (timer_q >= YELLOW_TIME)
                    state_d = ALL_RED;
            end
            default: state_d = NS_GREEN;
        endcase
    end

    // Moore outputs: depend only on current state
    always_comb begin
        light_ns = 3'b100;  // Default: Red
        light_ew = 3'b100;
        unique case (state_q)
            NS_GREEN:  begin light_ns = 3'b001; light_ew = 3'b100; end
            NS_YELLOW: begin light_ns = 3'b010; light_ew = 3'b100; end
            EW_GREEN:  begin light_ns = 3'b100; light_ew = 3'b001; end
            EW_YELLOW: begin light_ns = 3'b100; light_ew = 3'b010; end
            ALL_RED:   begin light_ns = 3'b100; light_ew = 3'b100; end
            default:   begin light_ns = 3'b100; light_ew = 3'b100; end
        endcase
    end

endmodule
