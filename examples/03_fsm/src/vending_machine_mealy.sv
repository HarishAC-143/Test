// Vending Machine Controller — Mealy FSM
// Accepts nickels (5c) and dimes (10c) to dispense a 15-cent item.
// Returns change if overpaid.
// Mealy machine: dispense output depends on state AND current coin input.

module vending_machine_mealy (
    input  logic clk,
    input  logic rst_n,
    input  logic nickel,    // 5-cent coin inserted
    input  logic dime,      // 10-cent coin inserted
    output logic dispense,  // item dispensed
    output logic change     // 5-cent change returned
);

    typedef enum logic [1:0] {
        S_0   = 2'b00,   // 0 cents collected
        S_5   = 2'b01,   // 5 cents collected
        S_10  = 2'b10    // 10 cents collected
    } state_t;

    state_t state, next_state;

    // State register
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= S_0;
        else
            state <= next_state;
    end

    // Next-state and Mealy output logic
    always_comb begin
        next_state = state;
        dispense   = 1'b0;
        change     = 1'b0;

        case (state)
            S_0: begin
                if (nickel)
                    next_state = S_5;
                else if (dime)
                    next_state = S_10;
            end

            S_5: begin
                if (nickel)
                    next_state = S_10;
                else if (dime) begin
                    // 5 + 10 = 15 cents -> dispense
                    next_state = S_0;
                    dispense   = 1'b1;
                end
            end

            S_10: begin
                if (nickel) begin
                    // 10 + 5 = 15 cents -> dispense
                    next_state = S_0;
                    dispense   = 1'b1;
                end else if (dime) begin
                    // 10 + 10 = 20 cents -> dispense + change
                    next_state = S_0;
                    dispense   = 1'b1;
                    change     = 1'b1;
                end
            end

            default: begin
                next_state = S_0;
            end
        endcase
    end

endmodule
