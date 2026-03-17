// Vending Machine FSM - Mealy Machine
// Accepts nickels (5c) and dimes (10c), dispenses item at 15c

module vending_machine (
    input  logic clk,
    input  logic rst_n,
    input  logic nickel,
    input  logic dime,
    output logic dispense,
    output logic change
);

    typedef enum logic [1:0] {
        IDLE    = 2'b00,    // 0 cents collected
        FIVE    = 2'b01,    // 5 cents collected
        TEN     = 2'b10     // 10 cents collected
    } state_e;

    state_e state, next_state;

    // State register
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= IDLE;
        else
            state <= next_state;
    end

    // Next-state and output logic (Mealy: output depends on state + input)
    always_comb begin
        next_state = state;
        dispense   = 1'b0;
        change     = 1'b0;

        case (state)
            IDLE: begin
                if (nickel)
                    next_state = FIVE;
                else if (dime)
                    next_state = TEN;
            end

            FIVE: begin
                if (nickel)
                    next_state = TEN;
                else if (dime) begin
                    next_state = IDLE;
                    dispense   = 1'b1;    // 5 + 10 = 15
                end
            end

            TEN: begin
                if (nickel) begin
                    next_state = IDLE;
                    dispense   = 1'b1;    // 10 + 5 = 15
                end else if (dime) begin
                    next_state = IDLE;
                    dispense   = 1'b1;    // 10 + 10 = 20, give change
                    change     = 1'b1;
                end
            end

            default: next_state = IDLE;
        endcase
    end

endmodule
