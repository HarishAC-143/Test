// UART Transmitter
// Sends 8-bit data with configurable baud rate.
// Frame format: 1 start bit, 8 data bits (LSB first), 1 stop bit.
// BAUD_DIV = (clk_freq / baud_rate) - 1   e.g., 50MHz / 115200 ≈ 433.

module uart_tx #(
    parameter BAUD_DIV   = 433,
    parameter CNT_WIDTH  = $clog2(BAUD_DIV + 1)
)(
    input  logic       clk,
    input  logic       rst_n,
    input  logic [7:0] tx_data,
    input  logic       tx_valid,
    output logic       tx_ready,
    output logic       tx_out
);

    typedef enum logic [1:0] {
        IDLE,
        START,
        DATA,
        STOP
    } state_t;

    state_t state, next_state;
    logic [CNT_WIDTH-1:0] baud_cnt;
    logic                 baud_tick;
    logic [2:0]           bit_idx;
    logic [7:0]           shift_reg;

    // Baud rate generator
    assign baud_tick = (baud_cnt == BAUD_DIV[CNT_WIDTH-1:0]);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            baud_cnt <= '0;
        else if (state == IDLE || baud_tick)
            baud_cnt <= '0;
        else
            baud_cnt <= baud_cnt + 1'b1;
    end

    // State register
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= IDLE;
        else
            state <= next_state;
    end

    // Shift register and bit index
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            shift_reg <= 8'hFF;
            bit_idx   <= '0;
        end else begin
            case (state)
                IDLE: begin
                    if (tx_valid) begin
                        shift_reg <= tx_data;
                        bit_idx   <= '0;
                    end
                end

                DATA: begin
                    if (baud_tick) begin
                        shift_reg <= {1'b1, shift_reg[7:1]};
                        bit_idx   <= bit_idx + 1'b1;
                    end
                end

                default: ;
            endcase
        end
    end

    // Next-state logic
    always_comb begin
        next_state = state;

        case (state)
            IDLE: begin
                if (tx_valid)
                    next_state = START;
            end

            START: begin
                if (baud_tick)
                    next_state = DATA;
            end

            DATA: begin
                if (baud_tick && bit_idx == 3'd7)
                    next_state = STOP;
            end

            STOP: begin
                if (baud_tick)
                    next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Outputs
    always_comb begin
        case (state)
            IDLE:    tx_out = 1'b1;          // line idle high
            START:   tx_out = 1'b0;          // start bit
            DATA:    tx_out = shift_reg[0];  // LSB first
            STOP:    tx_out = 1'b1;          // stop bit
            default: tx_out = 1'b1;
        endcase
    end

    assign tx_ready = (state == IDLE);

endmodule
