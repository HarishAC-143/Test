// Mealy Finite State Machine
// Sequence Detector: detects the bit pattern "1011" in a serial input stream
// Outputs depend on both current state AND inputs (Mealy characteristic)

module sequence_detector_mealy (
    input  logic clk,
    input  logic rst_n,
    input  logic bit_in,
    output logic detected
);

    typedef enum logic [2:0] {
        S_IDLE  = 3'b000,   // Waiting for first '1'
        S_GOT1  = 3'b001,   // Received "1"
        S_GOT10 = 3'b010,   // Received "10"
        S_GOT101 = 3'b011   // Received "101"
    } state_e;

    state_e state_q, state_d;

    // State register
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state_q <= S_IDLE;
        else
            state_q <= state_d;
    end

    // Next state and output logic (combined for Mealy)
    always_comb begin
        state_d  = state_q;
        detected = 1'b0;

        unique case (state_q)
            S_IDLE: begin
                state_d = bit_in ? S_GOT1 : S_IDLE;
            end

            S_GOT1: begin
                state_d = bit_in ? S_GOT1 : S_GOT10;
            end

            S_GOT10: begin
                state_d = bit_in ? S_GOT101 : S_IDLE;
            end

            S_GOT101: begin
                if (bit_in) begin
                    detected = 1'b1;   // Mealy: output asserted with input
                    state_d  = S_GOT1; // Overlapping detection
                end else begin
                    state_d = S_GOT10;
                end
            end

            default: state_d = S_IDLE;
        endcase
    end

endmodule
