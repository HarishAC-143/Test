// UART Receiver
// Receives 8-bit data with configurable baud rate.
// Frame format: 1 start bit, 8 data bits (LSB first), 1 stop bit.
// Uses 16x oversampling to find the center of each bit period.
// BAUD_DIV_16X = (clk_freq / (baud_rate * 16)) - 1   e.g., 50MHz / (115200*16) ≈ 26.

module uart_rx #(
    parameter BAUD_DIV_16X = 26,
    parameter CNT_WIDTH    = $clog2(BAUD_DIV_16X + 1)
)(
    input  logic       clk,
    input  logic       rst_n,
    input  logic       rx_in,
    output logic [7:0] rx_data,
    output logic       rx_valid,
    output logic       frame_error
);

    typedef enum logic [1:0] {
        IDLE,
        START,
        DATA,
        STOP
    } state_t;

    state_t state, next_state;

    // Synchronize asynchronous rx_in to local clock
    logic rx_sync, rx_meta;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_meta <= 1'b1;
            rx_sync <= 1'b1;
        end else begin
            rx_meta <= rx_in;
            rx_sync <= rx_meta;
        end
    end

    logic [CNT_WIDTH-1:0] sample_cnt;
    logic                 sample_tick;
    logic [3:0]           tick_cnt;    // 0..15 oversampling counter
    logic [2:0]           bit_idx;
    logic [7:0]           shift_reg;

    // 16x baud rate tick generator
    assign sample_tick = (sample_cnt == BAUD_DIV_16X[CNT_WIDTH-1:0]);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            sample_cnt <= '0;
        else if (state == IDLE || sample_tick)
            sample_cnt <= '0;
        else
            sample_cnt <= sample_cnt + 1'b1;
    end

    // State register
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= IDLE;
        else
            state <= next_state;
    end

    // Tick counter, bit index, shift register
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tick_cnt  <= '0;
            bit_idx   <= '0;
            shift_reg <= '0;
            rx_data   <= '0;
            rx_valid  <= 1'b0;
            frame_error <= 1'b0;
        end else begin
            rx_valid    <= 1'b0;
            frame_error <= 1'b0;

            case (state)
                IDLE: begin
                    tick_cnt <= '0;
                    bit_idx  <= '0;
                end

                START: begin
                    if (sample_tick) begin
                        if (tick_cnt == 4'd7) begin
                            // At center of start bit — verify it's still low
                            tick_cnt <= '0;
                        end else begin
                            tick_cnt <= tick_cnt + 1'b1;
                        end
                    end
                end

                DATA: begin
                    if (sample_tick) begin
                        if (tick_cnt == 4'd15) begin
                            // Sample at center of data bit
                            shift_reg <= {rx_sync, shift_reg[7:1]};
                            tick_cnt  <= '0;
                            bit_idx   <= bit_idx + 1'b1;
                        end else begin
                            tick_cnt <= tick_cnt + 1'b1;
                        end
                    end
                end

                STOP: begin
                    if (sample_tick) begin
                        if (tick_cnt == 4'd15) begin
                            rx_data     <= shift_reg;
                            rx_valid    <= 1'b1;
                            frame_error <= ~rx_sync;  // stop bit should be high
                            tick_cnt    <= '0;
                        end else begin
                            tick_cnt <= tick_cnt + 1'b1;
                        end
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
                if (!rx_sync)
                    next_state = START;
            end

            START: begin
                if (sample_tick && tick_cnt == 4'd7) begin
                    if (!rx_sync)
                        next_state = DATA;
                    else
                        next_state = IDLE;  // false start
                end
            end

            DATA: begin
                if (sample_tick && tick_cnt == 4'd15 && bit_idx == 3'd7)
                    next_state = STOP;
            end

            STOP: begin
                if (sample_tick && tick_cnt == 4'd15)
                    next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

endmodule
