// One-Hot Encoded FSM
// SPI Master Controller: uses one-hot encoding for faster decode on FPGAs
// One-hot is often preferred on FPGAs because it uses flip-flops (abundant)
// rather than LUTs for state decode

module spi_master_fsm (
    input  logic       clk,
    input  logic       rst_n,
    input  logic       start,
    input  logic       miso,
    input  logic [7:0] tx_data,
    output logic       sclk,
    output logic       mosi,
    output logic       cs_n,
    output logic [7:0] rx_data,
    output logic       done
);

    // One-hot state encoding
    typedef enum logic [4:0] {
        ST_IDLE     = 5'b00001,
        ST_LOAD     = 5'b00010,
        ST_SHIFT_LO = 5'b00100,  // SCLK low phase
        ST_SHIFT_HI = 5'b01000,  // SCLK high phase
        ST_DONE     = 5'b10000
    } state_e;

    state_e state_q, state_d;

    logic [7:0] shift_reg;
    logic [2:0] bit_cnt;

    // State register
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state_q <= ST_IDLE;
        else
            state_q <= state_d;
    end

    // Bit counter
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            bit_cnt <= '0;
        else if (state_q == ST_IDLE)
            bit_cnt <= '0;
        else if (state_q == ST_SHIFT_HI)
            bit_cnt <= bit_cnt + 1'b1;
    end

    // Shift register
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            shift_reg <= '0;
        else if (state_q == ST_LOAD)
            shift_reg <= tx_data;
        else if (state_q == ST_SHIFT_HI)
            shift_reg <= {shift_reg[6:0], miso};
    end

    // Next state logic
    always_comb begin
        state_d = state_q;
        unique case (1'b1)
            state_q[0]: begin  // IDLE
                if (start)
                    state_d = ST_LOAD;
            end
            state_q[1]: begin  // LOAD
                state_d = ST_SHIFT_LO;
            end
            state_q[2]: begin  // SHIFT_LO
                state_d = ST_SHIFT_HI;
            end
            state_q[3]: begin  // SHIFT_HI
                if (bit_cnt == 3'd7)
                    state_d = ST_DONE;
                else
                    state_d = ST_SHIFT_LO;
            end
            state_q[4]: begin  // DONE
                state_d = ST_IDLE;
            end
            default: state_d = ST_IDLE;
        endcase
    end

    // Outputs
    assign cs_n    = state_q[0];  // CS_N deasserted only in IDLE
    assign sclk    = state_q[3];  // SCLK high only in SHIFT_HI
    assign mosi    = shift_reg[7];
    assign done    = state_q[4];
    assign rx_data = shift_reg;

endmodule
