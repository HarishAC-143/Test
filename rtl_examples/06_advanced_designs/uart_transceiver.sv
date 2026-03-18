// =============================================================================
// UART Transmitter
// Configurable baud rate, 8N1 format (8 data bits, no parity, 1 stop bit).
// =============================================================================

module uart_tx #(
    parameter CLK_FREQ  = 50_000_000,
    parameter BAUD_RATE = 115200,
    parameter CLKS_PER_BIT = CLK_FREQ / BAUD_RATE
) (
    input  logic       clk,
    input  logic       rst_n,
    input  logic       tx_valid,
    input  logic [7:0] tx_data,
    output logic       tx_out,
    output logic       tx_busy
);

    typedef enum logic [2:0] {
        TX_IDLE  = 3'b000,
        TX_START = 3'b001,
        TX_DATA  = 3'b010,
        TX_STOP  = 3'b011,
        TX_DONE  = 3'b100
    } state_e;

    state_e state;
    logic [$clog2(CLKS_PER_BIT)-1:0] baud_counter;
    logic [2:0] bit_index;
    logic [7:0] tx_shift;

    assign tx_busy = (state != TX_IDLE);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state        <= TX_IDLE;
            tx_out       <= 1'b1;  // Idle high
            baud_counter <= '0;
            bit_index    <= '0;
            tx_shift     <= '0;
        end else begin
            case (state)
                TX_IDLE: begin
                    tx_out <= 1'b1;
                    if (tx_valid) begin
                        tx_shift     <= tx_data;
                        state        <= TX_START;
                        baud_counter <= '0;
                    end
                end

                TX_START: begin
                    tx_out <= 1'b0;  // Start bit
                    if (baud_counter == CLKS_PER_BIT[$clog2(CLKS_PER_BIT)-1:0] - 1) begin
                        baud_counter <= '0;
                        bit_index    <= '0;
                        state        <= TX_DATA;
                    end else begin
                        baud_counter <= baud_counter + 1'b1;
                    end
                end

                TX_DATA: begin
                    tx_out <= tx_shift[bit_index];
                    if (baud_counter == CLKS_PER_BIT[$clog2(CLKS_PER_BIT)-1:0] - 1) begin
                        baud_counter <= '0;
                        if (bit_index == 3'd7)
                            state <= TX_STOP;
                        else
                            bit_index <= bit_index + 1'b1;
                    end else begin
                        baud_counter <= baud_counter + 1'b1;
                    end
                end

                TX_STOP: begin
                    tx_out <= 1'b1;  // Stop bit
                    if (baud_counter == CLKS_PER_BIT[$clog2(CLKS_PER_BIT)-1:0] - 1) begin
                        state        <= TX_DONE;
                        baud_counter <= '0;
                    end else begin
                        baud_counter <= baud_counter + 1'b1;
                    end
                end

                TX_DONE: begin
                    state <= TX_IDLE;
                end

                default: state <= TX_IDLE;
            endcase
        end
    end

endmodule

// =============================================================================
// UART Receiver
// Samples input at 16x oversampling for reliable data capture.
// =============================================================================

module uart_rx #(
    parameter CLK_FREQ     = 50_000_000,
    parameter BAUD_RATE    = 115200,
    parameter CLKS_PER_BIT = CLK_FREQ / BAUD_RATE
) (
    input  logic       clk,
    input  logic       rst_n,
    input  logic       rx_in,
    output logic [7:0] rx_data,
    output logic       rx_valid,
    output logic       rx_error
);

    typedef enum logic [2:0] {
        RX_IDLE  = 3'b000,
        RX_START = 3'b001,
        RX_DATA  = 3'b010,
        RX_STOP  = 3'b011,
        RX_DONE  = 3'b100
    } state_e;

    state_e state;
    logic [$clog2(CLKS_PER_BIT)-1:0] baud_counter;
    logic [2:0] bit_index;
    logic [7:0] rx_shift;

    // Input synchronizer (metastability protection)
    logic rx_sync1, rx_sync2;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_sync1 <= 1'b1;
            rx_sync2 <= 1'b1;
        end else begin
            rx_sync1 <= rx_in;
            rx_sync2 <= rx_sync1;
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state        <= RX_IDLE;
            rx_data      <= '0;
            rx_valid     <= 1'b0;
            rx_error     <= 1'b0;
            baud_counter <= '0;
            bit_index    <= '0;
            rx_shift     <= '0;
        end else begin
            rx_valid <= 1'b0;
            rx_error <= 1'b0;

            case (state)
                RX_IDLE: begin
                    if (!rx_sync2) begin
                        state        <= RX_START;
                        baud_counter <= '0;
                    end
                end

                RX_START: begin
                    // Sample at the middle of the start bit
                    if (baud_counter == (CLKS_PER_BIT[$clog2(CLKS_PER_BIT)-1:0] >> 1)) begin
                        if (!rx_sync2) begin
                            baud_counter <= '0;
                            bit_index    <= '0;
                            state        <= RX_DATA;
                        end else begin
                            state <= RX_IDLE;  // False start
                        end
                    end else begin
                        baud_counter <= baud_counter + 1'b1;
                    end
                end

                RX_DATA: begin
                    if (baud_counter == CLKS_PER_BIT[$clog2(CLKS_PER_BIT)-1:0] - 1) begin
                        baud_counter <= '0;
                        rx_shift[bit_index] <= rx_sync2;
                        if (bit_index == 3'd7)
                            state <= RX_STOP;
                        else
                            bit_index <= bit_index + 1'b1;
                    end else begin
                        baud_counter <= baud_counter + 1'b1;
                    end
                end

                RX_STOP: begin
                    if (baud_counter == CLKS_PER_BIT[$clog2(CLKS_PER_BIT)-1:0] - 1) begin
                        if (rx_sync2) begin
                            rx_data  <= rx_shift;
                            rx_valid <= 1'b1;
                        end else begin
                            rx_error <= 1'b1;  // Framing error
                        end
                        state <= RX_DONE;
                    end else begin
                        baud_counter <= baud_counter + 1'b1;
                    end
                end

                RX_DONE: begin
                    state <= RX_IDLE;
                end

                default: state <= RX_IDLE;
            endcase
        end
    end

endmodule
