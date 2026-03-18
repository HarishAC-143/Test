// UART Receiver
// 16x oversampling with mid-bit sampling for noise immunity.
// 8N1 format (8 data bits, no parity, 1 stop bit).

module uart_rx #(
    parameter int CLK_FREQ  = 50_000_000,
    parameter int BAUD_RATE = 115200
) (
    input  logic       clk,
    input  logic       rst_n,
    input  logic       rx_in,
    output logic [7:0] rx_data,
    output logic       rx_valid,
    output logic       rx_error   // Framing error (stop bit not high)
);

    localparam int BAUD_DIV_16 = CLK_FREQ / (BAUD_RATE * 16);
    localparam int DIV_W       = $clog2(BAUD_DIV_16 + 1);

    typedef enum logic [1:0] {
        S_IDLE,
        S_START,
        S_DATA,
        S_STOP
    } state_t;

    state_t state;

    logic [DIV_W-1:0] tick_counter;
    logic              tick_16x;
    logic [3:0]        sample_counter;  // 0-15: counts 16x oversamples
    logic [7:0]        shift_reg;
    logic [2:0]        bit_index;
    logic              rx_sync;        // Synchronized input

    // 2-flop synchronizer for metastability
    logic rx_meta;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_meta <= 1'b1;
            rx_sync <= 1'b1;
        end else begin
            rx_meta <= rx_in;
            rx_sync <= rx_meta;
        end
    end

    // 16x baud tick generator
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tick_counter <= '0;
        end else if (tick_counter >= BAUD_DIV_16 - 1) begin
            tick_counter <= '0;
        end else begin
            tick_counter <= tick_counter + 1;
        end
    end

    assign tick_16x = (tick_counter == BAUD_DIV_16 - 1);

    // RX state machine
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state          <= S_IDLE;
            rx_data        <= '0;
            rx_valid       <= 1'b0;
            rx_error       <= 1'b0;
            shift_reg      <= '0;
            bit_index      <= '0;
            sample_counter <= '0;
        end else begin
            rx_valid <= 1'b0;
            rx_error <= 1'b0;

            if (tick_16x) begin
                unique case (state)
                    S_IDLE: begin
                        if (!rx_sync) begin
                            // Falling edge detected — potential start bit
                            state          <= S_START;
                            sample_counter <= '0;
                        end
                    end

                    S_START: begin
                        // Sample at midpoint (count 7) to confirm start bit
                        if (sample_counter == 4'd7) begin
                            if (!rx_sync) begin
                                // Valid start bit
                                state          <= S_DATA;
                                sample_counter <= '0;
                                bit_index      <= '0;
                            end else begin
                                // Glitch, return to idle
                                state <= S_IDLE;
                            end
                        end else begin
                            sample_counter <= sample_counter + 1;
                        end
                    end

                    S_DATA: begin
                        if (sample_counter == 4'd15) begin
                            // Sample data at the middle of each bit period
                            shift_reg <= {rx_sync, shift_reg[7:1]};
                            sample_counter <= '0;

                            if (bit_index == 3'd7) begin
                                state <= S_STOP;
                            end else begin
                                bit_index <= bit_index + 1;
                            end
                        end else begin
                            sample_counter <= sample_counter + 1;
                        end
                    end

                    S_STOP: begin
                        if (sample_counter == 4'd15) begin
                            if (rx_sync) begin
                                // Valid stop bit
                                rx_data  <= shift_reg;
                                rx_valid <= 1'b1;
                            end else begin
                                // Framing error
                                rx_error <= 1'b1;
                            end
                            state <= S_IDLE;
                        end else begin
                            sample_counter <= sample_counter + 1;
                        end
                    end
                endcase
            end
        end
    end

endmodule
