// Mealy FSM — Serial bit-pattern detector.
// Detects the sequence "1011" on the serial input.
// Overlapping detection is supported (e.g., "10110111" triggers twice).

module serial_detector_fsm (
    input  logic clk,
    input  logic rst_n,
    input  logic bit_in,
    output logic detected     // Mealy output — valid same cycle as last bit
);

    typedef enum logic [2:0] {
        S_IDLE = 3'b000,    // waiting for '1'
        S_1    = 3'b001,    // received "1"
        S_10   = 3'b010,    // received "10"
        S_101  = 3'b011     // received "101"
    } state_t;

    state_t state_q, state_d;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state_q <= S_IDLE;
        else
            state_q <= state_d;
    end

    always_comb begin
        state_d  = S_IDLE;
        detected = 1'b0;

        unique case (state_q)
            S_IDLE: begin
                state_d = bit_in ? S_1 : S_IDLE;
            end

            S_1: begin
                state_d = bit_in ? S_1 : S_10;
            end

            S_10: begin
                state_d = bit_in ? S_101 : S_IDLE;
            end

            S_101: begin
                if (bit_in) begin
                    detected = 1'b1;   // "1011" detected (Mealy)
                    state_d  = S_1;    // overlap: last '1' could start new sequence
                end else begin
                    state_d = S_10;    // "1010" — "10" prefix still valid
                end
            end

            default: state_d = S_IDLE;
        endcase
    end

endmodule
