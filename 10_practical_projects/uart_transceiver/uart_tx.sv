// UART Transmitter.
//
// Features:
// - Configurable baud rate via clock divider
// - 8-N-1 format (8 data bits, no parity, 1 stop bit)
// - Active-high busy signal
// - Single-cycle done pulse on completion
//
// Baud rate = clk_freq / (clk_div + 1)
// Example: 100 MHz clock, clk_div = 867 → 115200 baud

module uart_tx #(
    parameter int CLK_DIV_WIDTH = 16
)(
    input  logic                     clk,
    input  logic                     rst_n,
    input  logic [CLK_DIV_WIDTH-1:0] clk_div,   // baud rate divider
    input  logic [7:0]               tx_data,    // byte to transmit
    input  logic                     tx_valid,   // pulse to start transmission
    output logic                     tx_ready,   // ready to accept new data
    output logic                     txd          // serial output (active high)
);

    typedef enum logic [1:0] {
        TX_IDLE,
        TX_START,
        TX_DATA,
        TX_STOP
    } tx_state_t;

    tx_state_t state;
    logic [CLK_DIV_WIDTH-1:0] baud_cnt;
    logic                     baud_tick;
    logic [7:0]               shift_reg;
    logic [2:0]               bit_idx;

    // Baud rate generator
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            baud_cnt <= '0;
        end else if (state == TX_IDLE) begin
            baud_cnt <= '0;
        end else if (baud_cnt == clk_div) begin
            baud_cnt <= '0;
        end else begin
            baud_cnt <= baud_cnt + 1'b1;
        end
    end

    assign baud_tick = (baud_cnt == clk_div) && (state != TX_IDLE);

    // TX FSM
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= TX_IDLE;
            txd       <= 1'b1;    // idle high
            shift_reg <= '0;
            bit_idx   <= '0;
            tx_ready  <= 1'b1;
        end else begin
            unique case (state)
                TX_IDLE: begin
                    txd      <= 1'b1;
                    tx_ready <= 1'b1;
                    if (tx_valid) begin
                        shift_reg <= tx_data;
                        tx_ready  <= 1'b0;
                        state     <= TX_START;
                    end
                end

                TX_START: begin
                    txd <= 1'b0;    // start bit
                    if (baud_tick) begin
                        state   <= TX_DATA;
                        bit_idx <= '0;
                    end
                end

                TX_DATA: begin
                    txd <= shift_reg[0];
                    if (baud_tick) begin
                        shift_reg <= {1'b0, shift_reg[7:1]};
                        if (bit_idx == 3'd7)
                            state <= TX_STOP;
                        else
                            bit_idx <= bit_idx + 1'b1;
                    end
                end

                TX_STOP: begin
                    txd <= 1'b1;    // stop bit
                    if (baud_tick)
                        state <= TX_IDLE;
                end

                default: state <= TX_IDLE;
            endcase
        end
    end

endmodule
