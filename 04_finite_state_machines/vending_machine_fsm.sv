// Vending machine FSM — accepts 5-cent and 10-cent coins.
// Dispenses product when 15 cents or more is accumulated.
// Returns change if overpaid.

module vending_machine_fsm (
    input  logic clk,
    input  logic rst_n,
    input  logic nickel,      // 5-cent coin inserted
    input  logic dime,        // 10-cent coin inserted
    output logic dispense,    // product dispensed
    output logic return_nickel // return 5 cents change
);

    typedef enum logic [2:0] {
        S_0    = 3'b000,    // 0 cents
        S_5    = 3'b001,    // 5 cents
        S_10   = 3'b010,    // 10 cents
        S_15   = 3'b011,    // 15 cents — dispense
        S_20   = 3'b100     // 20 cents — dispense + change
    } state_t;

    state_t state_q, state_d;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state_q <= S_0;
        else
            state_q <= state_d;
    end

    always_comb begin
        state_d       = state_q;
        dispense      = 1'b0;
        return_nickel = 1'b0;

        unique case (state_q)
            S_0: begin
                if (nickel)     state_d = S_5;
                else if (dime)  state_d = S_10;
            end

            S_5: begin
                if (nickel)     state_d = S_10;
                else if (dime)  state_d = S_15;
            end

            S_10: begin
                if (nickel)     state_d = S_15;
                else if (dime)  state_d = S_20;
            end

            S_15: begin
                dispense = 1'b1;
                state_d  = S_0;
            end

            S_20: begin
                dispense      = 1'b1;
                return_nickel = 1'b1;
                state_d       = S_0;
            end

            default: state_d = S_0;
        endcase
    end

endmodule
