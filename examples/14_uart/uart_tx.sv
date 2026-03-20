// ============================================================================
// UART Transmitter
// ============================================================================
// Configurable UART transmitter with:
//   - Parameterized clock frequency and baud rate
//   - Configurable data bits (5-8)
//   - Start bit, data bits (LSB first), stop bit
//   - Valid/ready handshake for data input
//
// Timing: each bit lasts CLK_FREQ / BAUD_RATE clock cycles.
// ============================================================================

module uart_tx #(
    parameter int CLK_FREQ  = 50_000_000,
    parameter int BAUD_RATE = 115200,
    parameter int DATA_BITS = 8
)(
    input  logic                  clk,
    input  logic                  rst_n,
    input  logic [DATA_BITS-1:0]  tx_data,
    input  logic                  tx_valid,
    output logic                  tx_ready,
    output logic                  tx_out
);

    localparam int CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;
    localparam int BIT_CNT_W   = $clog2(CLKS_PER_BIT + 1);

    typedef enum logic [1:0] {
        TX_IDLE,
        TX_START,
        TX_DATA,
        TX_STOP
    } tx_state_t;

    tx_state_t             state;
    logic [BIT_CNT_W-1:0]  clk_cnt;
    logic [2:0]            bit_idx;
    logic [DATA_BITS-1:0]  shift_reg;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= TX_IDLE;
            tx_out    <= 1'b1;        // idle line is high
            tx_ready  <= 1'b1;
            clk_cnt   <= '0;
            bit_idx   <= '0;
            shift_reg <= '0;
        end else begin
            unique case (state)
                TX_IDLE: begin
                    tx_out   <= 1'b1;
                    tx_ready <= 1'b1;
                    if (tx_valid && tx_ready) begin
                        shift_reg <= tx_data;
                        tx_ready  <= 1'b0;
                        clk_cnt   <= '0;
                        state     <= TX_START;
                    end
                end

                TX_START: begin
                    tx_out <= 1'b0;   // start bit = low
                    if (clk_cnt == BIT_CNT_W'(CLKS_PER_BIT - 1)) begin
                        clk_cnt <= '0;
                        bit_idx <= '0;
                        state   <= TX_DATA;
                    end else begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end
                end

                TX_DATA: begin
                    tx_out <= shift_reg[bit_idx];
                    if (clk_cnt == BIT_CNT_W'(CLKS_PER_BIT - 1)) begin
                        clk_cnt <= '0;
                        if (bit_idx == 3'(DATA_BITS - 1))
                            state <= TX_STOP;
                        else
                            bit_idx <= bit_idx + 3'd1;
                    end else begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end
                end

                TX_STOP: begin
                    tx_out <= 1'b1;   // stop bit = high
                    if (clk_cnt == BIT_CNT_W'(CLKS_PER_BIT - 1)) begin
                        clk_cnt <= '0;
                        state   <= TX_IDLE;
                    end else begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end
                end
            endcase
        end
    end

endmodule
