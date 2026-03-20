// ============================================================================
// SPI Master Controller
// ============================================================================
// A configurable SPI master supporting all four SPI modes:
//
//   Mode | CPOL | CPHA | Idle Clock | Sample Edge
//   -----+------+------+------------+-------------
//     0  |  0   |  0   |    Low     | Rising
//     1  |  0   |  1   |    Low     | Falling
//     2  |  1   |  0   |    High    | Falling
//     3  |  1   |  1   |    High    | Rising
//
// Features:
//   - Parameterized SPI clock frequency via clock divider
//   - Configurable data width
//   - MSB-first transmission
//   - Directly usable with flash, ADC, DAC, and sensor SPI slaves
// ============================================================================

module spi_master #(
    parameter int CLK_FREQ   = 50_000_000,
    parameter int SPI_FREQ   = 1_000_000,
    parameter int DATA_WIDTH = 8
)(
    input  logic                   clk,
    input  logic                   rst_n,

    // Control interface
    input  logic [1:0]             spi_mode,    // {CPOL, CPHA}
    input  logic                   start,
    input  logic [DATA_WIDTH-1:0]  tx_data,
    output logic [DATA_WIDTH-1:0]  rx_data,
    output logic                   busy,
    output logic                   done,

    // SPI physical interface
    output logic                   sclk,
    output logic                   mosi,
    input  logic                   miso,
    output logic                   cs_n
);

    localparam int HALF_PERIOD = CLK_FREQ / (2 * SPI_FREQ);
    localparam int CNT_W       = $clog2(HALF_PERIOD + 1);
    localparam int BIT_W       = $clog2(DATA_WIDTH + 1);

    typedef enum logic [1:0] {
        S_IDLE,
        S_LEADING,
        S_TRAILING,
        S_DONE
    } state_t;

    state_t              state;
    logic [CNT_W-1:0]    clk_cnt;
    logic [BIT_W-1:0]    bit_cnt;
    logic [DATA_WIDTH-1:0] tx_shift, rx_shift;
    logic                cpol, cpha;
    logic                sclk_int;

    assign cpol = spi_mode[1];
    assign cpha = spi_mode[0];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state    <= S_IDLE;
            sclk_int <= 1'b0;
            mosi     <= 1'b0;
            cs_n     <= 1'b1;
            busy     <= 1'b0;
            done     <= 1'b0;
            tx_shift <= '0;
            rx_shift <= '0;
            clk_cnt  <= '0;
            bit_cnt  <= '0;
            rx_data  <= '0;
        end else begin
            done <= 1'b0;

            unique case (state)
                S_IDLE: begin
                    sclk_int <= 1'b0;
                    cs_n     <= 1'b1;
                    busy     <= 1'b0;

                    if (start) begin
                        tx_shift <= tx_data;
                        rx_shift <= '0;
                        bit_cnt  <= '0;
                        clk_cnt  <= '0;
                        cs_n     <= 1'b0;
                        busy     <= 1'b1;
                        mosi     <= tx_data[DATA_WIDTH-1]; // MSB first

                        if (cpha) begin
                            state <= S_LEADING;
                        end else begin
                            state <= S_TRAILING;
                        end
                    end
                end

                S_LEADING: begin
                    if (clk_cnt == CNT_W'(HALF_PERIOD - 1)) begin
                        clk_cnt  <= '0;
                        sclk_int <= ~sclk_int;

                        if (!cpha) begin
                            // CPHA=0: sample on leading edge
                            rx_shift <= {rx_shift[DATA_WIDTH-2:0], miso};
                        end else begin
                            // CPHA=1: shift out on leading edge
                            mosi     <= tx_shift[DATA_WIDTH-1];
                            tx_shift <= {tx_shift[DATA_WIDTH-2:0], 1'b0};
                        end

                        state <= S_TRAILING;
                    end else begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end
                end

                S_TRAILING: begin
                    if (clk_cnt == CNT_W'(HALF_PERIOD - 1)) begin
                        clk_cnt  <= '0;
                        sclk_int <= ~sclk_int;

                        if (!cpha) begin
                            // CPHA=0: shift out on trailing edge
                            mosi     <= tx_shift[DATA_WIDTH-1];
                            tx_shift <= {tx_shift[DATA_WIDTH-2:0], 1'b0};
                        end else begin
                            // CPHA=1: sample on trailing edge
                            rx_shift <= {rx_shift[DATA_WIDTH-2:0], miso};
                        end

                        bit_cnt <= bit_cnt + 1'b1;

                        if (bit_cnt == BIT_W'(DATA_WIDTH - 1)) begin
                            state <= S_DONE;
                        end else begin
                            state <= S_LEADING;
                        end
                    end else begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end
                end

                S_DONE: begin
                    cs_n     <= 1'b1;
                    sclk_int <= 1'b0;
                    rx_data  <= rx_shift;
                    done     <= 1'b1;
                    busy     <= 1'b0;
                    state    <= S_IDLE;
                end
            endcase
        end
    end

    assign sclk = sclk_int ^ cpol;

endmodule
