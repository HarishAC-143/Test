// SPI Master Controller.
//
// Features:
// - All 4 SPI modes (CPOL/CPHA combinations)
// - Configurable clock divider
// - Parameterized data width (default 8-bit)
// - Active-low chip select
// - MSB-first or LSB-first
//
// SPI Modes:
//   Mode 0: CPOL=0, CPHA=0 — clock idle low,  data sampled on rising edge
//   Mode 1: CPOL=0, CPHA=1 — clock idle low,  data sampled on falling edge
//   Mode 2: CPOL=1, CPHA=0 — clock idle high, data sampled on falling edge
//   Mode 3: CPOL=1, CPHA=1 — clock idle high, data sampled on rising edge

module spi_master #(
    parameter int DATA_WIDTH   = 8,
    parameter int CLK_DIV_BITS = 8     // SCLK = clk / (2 * (clk_div + 1))
)(
    input  logic                    clk,
    input  logic                    rst_n,

    // Configuration
    input  logic [CLK_DIV_BITS-1:0] clk_div,    // clock divider value
    input  logic                    cpol,        // clock polarity
    input  logic                    cpha,        // clock phase
    input  logic                    msb_first,   // 1 = MSB first, 0 = LSB first

    // Control interface
    input  logic                    start,       // pulse to begin transaction
    input  logic [DATA_WIDTH-1:0]   tx_data,     // data to transmit
    output logic [DATA_WIDTH-1:0]   rx_data,     // received data
    output logic                    busy,
    output logic                    done,        // single-cycle pulse on completion

    // SPI pins
    output logic                    sclk,
    output logic                    mosi,
    input  logic                    miso,
    output logic                    cs_n
);

    localparam int BIT_CNT_W = $clog2(DATA_WIDTH);

    typedef enum logic [2:0] {
        S_IDLE,
        S_SETUP,        // pre-clock setup time
        S_TRANSFER,     // shifting data
        S_DONE
    } state_t;

    state_t state;

    logic [CLK_DIV_BITS-1:0] clk_cnt;
    logic                    sclk_int;
    logic                    sclk_prev;
    logic                    sclk_rising;
    logic                    sclk_falling;
    logic [DATA_WIDTH-1:0]   shift_reg;
    logic [BIT_CNT_W:0]     bit_cnt;
    logic                    sample_edge;
    logic                    shift_edge;

    assign sclk_rising  = sclk_int && !sclk_prev;
    assign sclk_falling = !sclk_int && sclk_prev;

    // Determine which edge samples and which shifts based on mode
    always_comb begin
        if (cpha == 1'b0) begin
            sample_edge = cpol ? sclk_falling : sclk_rising;
            shift_edge  = cpol ? sclk_rising  : sclk_falling;
        end else begin
            sample_edge = cpol ? sclk_rising  : sclk_falling;
            shift_edge  = cpol ? sclk_falling : sclk_rising;
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= S_IDLE;
            sclk_int  <= 1'b0;
            sclk_prev <= 1'b0;
            cs_n      <= 1'b1;
            shift_reg <= '0;
            rx_data   <= '0;
            bit_cnt   <= '0;
            clk_cnt   <= '0;
            busy      <= 1'b0;
            done      <= 1'b0;
            mosi      <= 1'b0;
        end else begin
            done      <= 1'b0;
            sclk_prev <= sclk_int;

            unique case (state)
                S_IDLE: begin
                    sclk_int <= cpol;
                    cs_n     <= 1'b1;
                    busy     <= 1'b0;

                    if (start) begin
                        shift_reg <= tx_data;
                        bit_cnt   <= '0;
                        clk_cnt   <= '0;
                        cs_n      <= 1'b0;
                        busy      <= 1'b1;

                        if (msb_first)
                            mosi <= tx_data[DATA_WIDTH-1];
                        else
                            mosi <= tx_data[0];

                        state <= cpha ? S_SETUP : S_TRANSFER;
                    end
                end

                S_SETUP: begin
                    if (clk_cnt == clk_div) begin
                        clk_cnt  <= '0;
                        sclk_int <= ~sclk_int;
                        state    <= S_TRANSFER;
                    end else begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end
                end

                S_TRANSFER: begin
                    if (clk_cnt == clk_div) begin
                        clk_cnt  <= '0;
                        sclk_int <= ~sclk_int;
                    end else begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end

                    if (sample_edge) begin
                        if (msb_first)
                            shift_reg <= {shift_reg[DATA_WIDTH-2:0], miso};
                        else
                            shift_reg <= {miso, shift_reg[DATA_WIDTH-1:1]};
                    end

                    if (shift_edge) begin
                        bit_cnt <= bit_cnt + 1'b1;

                        if (bit_cnt == DATA_WIDTH[BIT_CNT_W:0] - 1) begin
                            state <= S_DONE;
                        end else begin
                            if (msb_first)
                                mosi <= shift_reg[DATA_WIDTH-2];
                            else
                                mosi <= shift_reg[1];
                        end
                    end
                end

                S_DONE: begin
                    sclk_int <= cpol;
                    rx_data  <= shift_reg;
                    done     <= 1'b1;
                    cs_n     <= 1'b1;
                    state    <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end

    assign sclk = sclk_int;

endmodule
