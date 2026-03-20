// UART Receiver with 16x oversampling.
//
// Features:
// - 16x oversampling for robust bit-center sampling
// - Start-bit validation (rejects glitches)
// - 8-N-1 format
// - rx_valid pulse when a byte is received
// - Frame error detection

module uart_rx #(
    parameter int CLK_DIV_WIDTH = 16
)(
    input  logic                     clk,
    input  logic                     rst_n,
    input  logic [CLK_DIV_WIDTH-1:0] clk_div,   // baud rate divider (for 1x rate)
    input  logic                     rxd,        // serial input
    output logic [7:0]               rx_data,    // received byte
    output logic                     rx_valid,   // pulse when byte ready
    output logic                     frame_error // stop bit was not high
);

    // 16x oversampling: sample tick = clk / ((clk_div + 1) / 16)
    localparam int OVERSAMPLE = 16;

    typedef enum logic [1:0] {
        RX_IDLE,
        RX_START,
        RX_DATA,
        RX_STOP
    } rx_state_t;

    rx_state_t state;

    logic [CLK_DIV_WIDTH-1:0] tick_div;
    logic [CLK_DIV_WIDTH-1:0] tick_cnt;
    logic                     tick_16x;
    logic [3:0]               sample_cnt;  // 0-15 within each bit period
    logic [7:0]               shift_reg;
    logic [2:0]               bit_idx;

    // Synchronized RXD (double-flop for metastability protection)
    logic rxd_sync1, rxd_sync2;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rxd_sync1 <= 1'b1;
            rxd_sync2 <= 1'b1;
        end else begin
            rxd_sync1 <= rxd;
            rxd_sync2 <= rxd_sync1;
        end
    end

    // 16x baud tick generator
    assign tick_div = clk_div >> 4;  // divide by 16

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tick_cnt <= '0;
        end else if (state == RX_IDLE) begin
            tick_cnt <= '0;
        end else if (tick_cnt >= tick_div) begin
            tick_cnt <= '0;
        end else begin
            tick_cnt <= tick_cnt + 1'b1;
        end
    end

    assign tick_16x = (tick_cnt >= tick_div) && (state != RX_IDLE);

    // RX FSM
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state       <= RX_IDLE;
            rx_data     <= '0;
            rx_valid    <= 1'b0;
            frame_error <= 1'b0;
            shift_reg   <= '0;
            bit_idx     <= '0;
            sample_cnt  <= '0;
        end else begin
            rx_valid    <= 1'b0;
            frame_error <= 1'b0;

            unique case (state)
                RX_IDLE: begin
                    if (!rxd_sync2) begin
                        state      <= RX_START;
                        sample_cnt <= '0;
                    end
                end

                RX_START: begin
                    if (tick_16x) begin
                        if (sample_cnt == 4'd7) begin
                            if (!rxd_sync2) begin
                                state      <= RX_DATA;
                                sample_cnt <= '0;
                                bit_idx    <= '0;
                            end else begin
                                state <= RX_IDLE; // false start
                            end
                        end else begin
                            sample_cnt <= sample_cnt + 1'b1;
                        end
                    end
                end

                RX_DATA: begin
                    if (tick_16x) begin
                        if (sample_cnt == 4'd15) begin
                            sample_cnt <= '0;
                            shift_reg  <= {rxd_sync2, shift_reg[7:1]};
                            if (bit_idx == 3'd7)
                                state <= RX_STOP;
                            else
                                bit_idx <= bit_idx + 1'b1;
                        end else begin
                            sample_cnt <= sample_cnt + 1'b1;
                        end
                    end
                end

                RX_STOP: begin
                    if (tick_16x) begin
                        if (sample_cnt == 4'd15) begin
                            rx_data     <= shift_reg;
                            rx_valid    <= 1'b1;
                            frame_error <= !rxd_sync2;  // stop bit should be high
                            state       <= RX_IDLE;
                        end else begin
                            sample_cnt <= sample_cnt + 1'b1;
                        end
                    end
                end

                default: state <= RX_IDLE;
            endcase
        end
    end

endmodule
