// ============================================================================
// UART Receiver
// ============================================================================
// Configurable UART receiver with:
//   - Parameterized clock frequency and baud rate
//   - Configurable data bits (5-8)
//   - Mid-bit sampling for noise immunity
//   - Input synchronization (2-flop CDC) for the rx_in pin
//   - Single-cycle rx_valid pulse on successful reception
//
// The receiver samples at the middle of each bit period for optimal
// noise margin. It verifies the start bit at mid-point before proceeding.
// ============================================================================

module uart_rx #(
    parameter int CLK_FREQ  = 50_000_000,
    parameter int BAUD_RATE = 115200,
    parameter int DATA_BITS = 8
)(
    input  logic                  clk,
    input  logic                  rst_n,
    input  logic                  rx_in,
    output logic [DATA_BITS-1:0]  rx_data,
    output logic                  rx_valid,
    output logic                  rx_error    // stop-bit framing error
);

    localparam int CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;
    localparam int BIT_CNT_W   = $clog2(CLKS_PER_BIT + 1);

    typedef enum logic [1:0] {
        RX_IDLE,
        RX_START,
        RX_DATA,
        RX_STOP
    } rx_state_t;

    rx_state_t             state;
    logic [BIT_CNT_W-1:0]  clk_cnt;
    logic [2:0]            bit_idx;
    logic [DATA_BITS-1:0]  shift_reg;

    // Synchronize async rx_in to local clock domain
    logic rx_sync;
    (* async_reg = "true" *)
    logic [1:0] rx_meta;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            rx_meta <= 2'b11;
        else
            rx_meta <= {rx_meta[0], rx_in};
    end
    assign rx_sync = rx_meta[1];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= RX_IDLE;
            rx_valid  <= 1'b0;
            rx_error  <= 1'b0;
            rx_data   <= '0;
            clk_cnt   <= '0;
            bit_idx   <= '0;
            shift_reg <= '0;
        end else begin
            rx_valid <= 1'b0;
            rx_error <= 1'b0;

            unique case (state)
                RX_IDLE: begin
                    if (!rx_sync) begin   // falling edge → potential start bit
                        clk_cnt <= '0;
                        state   <= RX_START;
                    end
                end

                RX_START: begin
                    if (clk_cnt == BIT_CNT_W'(CLKS_PER_BIT / 2)) begin
                        if (!rx_sync) begin   // confirm start bit at midpoint
                            clk_cnt <= '0;
                            bit_idx <= '0;
                            state   <= RX_DATA;
                        end else begin
                            state <= RX_IDLE;  // false start
                        end
                    end else begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end
                end

                RX_DATA: begin
                    if (clk_cnt == BIT_CNT_W'(CLKS_PER_BIT - 1)) begin
                        clk_cnt <= '0;
                        shift_reg[bit_idx] <= rx_sync;
                        if (bit_idx == 3'(DATA_BITS - 1))
                            state <= RX_STOP;
                        else
                            bit_idx <= bit_idx + 3'd1;
                    end else begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end
                end

                RX_STOP: begin
                    if (clk_cnt == BIT_CNT_W'(CLKS_PER_BIT - 1)) begin
                        clk_cnt <= '0;
                        if (rx_sync) begin    // valid stop bit
                            rx_data  <= shift_reg;
                            rx_valid <= 1'b1;
                        end else begin
                            rx_error <= 1'b1; // framing error
                        end
                        state <= RX_IDLE;
                    end else begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end
                end
            endcase
        end
    end

endmodule
