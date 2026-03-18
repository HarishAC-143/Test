// UART Transmitter
// Configurable baud rate, 8N1 format (8 data bits, no parity, 1 stop bit).
// Uses a baud-rate tick generator for precise timing.

module uart_tx #(
    parameter int CLK_FREQ = 50_000_000,
    parameter int BAUD_RATE = 115200
) (
    input  logic       clk,
    input  logic       rst_n,
    input  logic       tx_start,
    input  logic [7:0] tx_data,
    output logic       tx_out,
    output logic       tx_busy,
    output logic       tx_done
);

    localparam int BAUD_DIV = CLK_FREQ / BAUD_RATE;
    localparam int DIV_W    = $clog2(BAUD_DIV + 1);

    typedef enum logic [1:0] {
        S_IDLE,
        S_START,
        S_DATA,
        S_STOP
    } state_t;

    state_t state;

    logic [DIV_W-1:0] baud_counter;
    logic              baud_tick;
    logic [7:0]        shift_reg;
    logic [2:0]        bit_index;

    // Baud rate generator
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            baud_counter <= '0;
        end else if (state == S_IDLE) begin
            baud_counter <= '0;
        end else if (baud_counter >= BAUD_DIV - 1) begin
            baud_counter <= '0;
        end else begin
            baud_counter <= baud_counter + 1;
        end
    end

    assign baud_tick = (baud_counter == BAUD_DIV - 1);

    // TX state machine
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= S_IDLE;
            tx_out    <= 1'b1;   // Idle high
            tx_busy   <= 1'b0;
            tx_done   <= 1'b0;
            shift_reg <= '0;
            bit_index <= '0;
        end else begin
            tx_done <= 1'b0;

            unique case (state)
                S_IDLE: begin
                    tx_out <= 1'b1;
                    if (tx_start) begin
                        state     <= S_START;
                        shift_reg <= tx_data;
                        tx_busy   <= 1'b1;
                    end
                end

                S_START: begin
                    tx_out <= 1'b0;  // Start bit
                    if (baud_tick) begin
                        state     <= S_DATA;
                        bit_index <= '0;
                    end
                end

                S_DATA: begin
                    tx_out <= shift_reg[0];  // LSB first
                    if (baud_tick) begin
                        shift_reg <= {1'b0, shift_reg[7:1]};
                        if (bit_index == 3'd7) begin
                            state <= S_STOP;
                        end else begin
                            bit_index <= bit_index + 1;
                        end
                    end
                end

                S_STOP: begin
                    tx_out <= 1'b1;  // Stop bit
                    if (baud_tick) begin
                        state   <= S_IDLE;
                        tx_busy <= 1'b0;
                        tx_done <= 1'b1;
                    end
                end
            endcase
        end
    end

endmodule
