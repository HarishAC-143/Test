// =============================================================================
// Mealy FSM — Sequence Detector (detects "1011")
// Output depends on BOTH current state AND input.
// Detects one clock cycle earlier than the Moore equivalent.
// =============================================================================

module mealy_sequence_detector (
    input  logic clk,
    input  logic rst_n,
    input  logic data_in,
    output logic detected
);

    typedef enum logic [1:0] {
        S_IDLE = 2'b00,
        S_1    = 2'b01,
        S_10   = 2'b10,
        S_101  = 2'b11
    } state_e;

    state_e current_state, next_state;

    // State register
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            current_state <= S_IDLE;
        else
            current_state <= next_state;
    end

    // Next state logic and output (Mealy: output depends on state + input)
    always_comb begin
        next_state = current_state;
        detected   = 1'b0;

        case (current_state)
            S_IDLE: begin
                next_state = data_in ? S_1 : S_IDLE;
            end

            S_1: begin
                next_state = data_in ? S_1 : S_10;
            end

            S_10: begin
                next_state = data_in ? S_101 : S_IDLE;
            end

            S_101: begin
                if (data_in) begin
                    detected   = 1'b1;   // "1011" detected on this cycle
                    next_state = S_1;     // Overlap: last '1' can start new seq
                end else begin
                    next_state = S_10;
                end
            end

            default: next_state = S_IDLE;
        endcase
    end

endmodule
