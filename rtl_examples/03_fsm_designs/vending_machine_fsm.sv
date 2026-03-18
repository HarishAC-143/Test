// =============================================================================
// Vending Machine Controller FSM
// Accepts 5-cent (nickel) and 10-cent (dime) coins.
// Dispenses product when 25 cents accumulated; returns change.
// =============================================================================

module vending_machine #(
    parameter PRICE = 25  // cents
) (
    input  logic       clk,
    input  logic       rst_n,
    input  logic       nickel_in,    // 5 cents inserted
    input  logic       dime_in,      // 10 cents inserted
    output logic       dispense,     // Product dispensed
    output logic [4:0] change,       // Change returned
    output logic [4:0] current_total // Current accumulated amount (debug)
);

    typedef enum logic [2:0] {
        S_0   = 3'b000,  // 0 cents
        S_5   = 3'b001,  // 5 cents
        S_10  = 3'b010,  // 10 cents
        S_15  = 3'b011,  // 15 cents
        S_20  = 3'b100,  // 20 cents
        S_DONE = 3'b101  // Dispense
    } state_e;

    state_e state, next_state;
    logic [4:0] next_change;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= S_0;
        else
            state <= next_state;
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            change <= '0;
        else
            change <= next_change;
    end

    always_comb begin
        next_state  = state;
        next_change = '0;
        dispense    = 1'b0;

        case (state)
            S_0: begin
                current_total = 5'd0;
                if (nickel_in)      next_state = S_5;
                else if (dime_in)   next_state = S_10;
            end

            S_5: begin
                current_total = 5'd5;
                if (nickel_in)      next_state = S_10;
                else if (dime_in)   next_state = S_15;
            end

            S_10: begin
                current_total = 5'd10;
                if (nickel_in)      next_state = S_15;
                else if (dime_in)   next_state = S_20;
            end

            S_15: begin
                current_total = 5'd15;
                if (nickel_in)      next_state = S_20;
                else if (dime_in) begin
                    next_state  = S_DONE;
                    next_change = 5'd0;
                end
            end

            S_20: begin
                current_total = 5'd20;
                if (nickel_in) begin
                    next_state  = S_DONE;
                    next_change = 5'd0;
                end else if (dime_in) begin
                    next_state  = S_DONE;
                    next_change = 5'd5;  // 30 - 25 = 5 cents change
                end
            end

            S_DONE: begin
                current_total = 5'd25;
                dispense      = 1'b1;
                next_state    = S_0;
            end

            default: begin
                current_total = 5'd0;
                next_state    = S_0;
            end
        endcase
    end

endmodule
