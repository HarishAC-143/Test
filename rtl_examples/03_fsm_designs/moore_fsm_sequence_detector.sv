// =============================================================================
// Moore FSM — Sequence Detector (detects "1011")
// Output depends ONLY on the current state.
// Overlapping detection supported.
// =============================================================================

module moore_sequence_detector (
    input  logic clk,
    input  logic rst_n,
    input  logic data_in,
    output logic detected
);

    typedef enum logic [2:0] {
        S_IDLE = 3'b000,
        S_1    = 3'b001,
        S_10   = 3'b010,
        S_101  = 3'b011,
        S_1011 = 3'b100
    } state_e;

    state_e current_state, next_state;

    // State register
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            current_state <= S_IDLE;
        else
            current_state <= next_state;
    end

    // Next state logic
    always_comb begin
        case (current_state)
            S_IDLE: next_state = data_in ? S_1    : S_IDLE;
            S_1:    next_state = data_in ? S_1    : S_10;
            S_10:   next_state = data_in ? S_101  : S_IDLE;
            S_101:  next_state = data_in ? S_1011 : S_10;
            S_1011: next_state = data_in ? S_1    : S_10;
            default: next_state = S_IDLE;
        endcase
    end

    // Output logic (Moore: depends only on state)
    assign detected = (current_state == S_1011);

endmodule
