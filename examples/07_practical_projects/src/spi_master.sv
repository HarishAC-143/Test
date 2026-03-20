// SPI Master Controller
// Supports all four SPI modes (CPOL/CPHA combinations).
// Transfers 8 bits per transaction, MSB first.
// CLK_DIV sets sclk frequency: f_sclk = f_clk / (2 * (CLK_DIV + 1)).

module spi_master #(
    parameter CLK_DIV  = 4,
    parameter CNT_WIDTH = $clog2(CLK_DIV + 1)
)(
    input  logic       clk,
    input  logic       rst_n,
    // Configuration
    input  logic       cpol,        // clock polarity
    input  logic       cpha,        // clock phase
    // Control
    input  logic       start,
    input  logic [7:0] tx_data,
    output logic [7:0] rx_data,
    output logic       busy,
    output logic       done,
    // SPI bus
    output logic       sclk,
    output logic       mosi,
    input  logic       miso,
    output logic       cs_n
);

    typedef enum logic [2:0] {
        IDLE,
        ASSERT_CS,
        LEADING_EDGE,
        TRAILING_EDGE,
        DEASSERT_CS,
        COMPLETE
    } state_t;

    state_t state, next_state;

    logic [CNT_WIDTH-1:0] clk_cnt;
    logic                 clk_tick;
    logic [2:0]           bit_cnt;
    logic [7:0]           tx_shift, rx_shift;
    logic                 sclk_int;

    assign clk_tick = (clk_cnt == CLK_DIV[CNT_WIDTH-1:0]);

    // Clock divider
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            clk_cnt <= '0;
        else if (state == IDLE || clk_tick)
            clk_cnt <= '0;
        else
            clk_cnt <= clk_cnt + 1'b1;
    end

    // State register
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= IDLE;
        else
            state <= next_state;
    end

    // Data path
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx_shift <= '0;
            rx_shift <= '0;
            rx_data  <= '0;
            bit_cnt  <= '0;
            sclk_int <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    sclk_int <= cpol;
                    if (start) begin
                        tx_shift <= tx_data;
                        bit_cnt  <= '0;
                    end
                end

                ASSERT_CS: ;

                LEADING_EDGE: begin
                    if (clk_tick) begin
                        sclk_int <= ~sclk_int;
                        if (cpha == 1'b0) begin
                            // Sample on leading edge
                            rx_shift <= {rx_shift[6:0], miso};
                        end else begin
                            // Shift out on leading edge
                            mosi <= tx_shift[7];
                        end
                    end
                end

                TRAILING_EDGE: begin
                    if (clk_tick) begin
                        sclk_int <= ~sclk_int;
                        if (cpha == 1'b0) begin
                            // Shift out on trailing edge
                            tx_shift <= {tx_shift[6:0], 1'b0};
                        end else begin
                            // Sample on trailing edge
                            rx_shift <= {rx_shift[6:0], miso};
                            tx_shift <= {tx_shift[6:0], 1'b0};
                        end
                        bit_cnt <= bit_cnt + 1'b1;
                    end
                end

                DEASSERT_CS: begin
                    sclk_int <= cpol;
                end

                COMPLETE: begin
                    rx_data <= rx_shift;
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
                if (start)
                    next_state = ASSERT_CS;
            end

            ASSERT_CS: begin
                next_state = LEADING_EDGE;
            end

            LEADING_EDGE: begin
                if (clk_tick)
                    next_state = TRAILING_EDGE;
            end

            TRAILING_EDGE: begin
                if (clk_tick) begin
                    if (bit_cnt == 3'd7)
                        next_state = DEASSERT_CS;
                    else
                        next_state = LEADING_EDGE;
                end
            end

            DEASSERT_CS: begin
                if (clk_tick)
                    next_state = COMPLETE;
            end

            COMPLETE: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    assign sclk = sclk_int;
    assign cs_n = (state == IDLE || state == COMPLETE);
    assign busy = (state != IDLE);
    assign done = (state == COMPLETE);

    // MOSI output (directly driven from shift register MSB for CPHA=0)
    always_comb begin
        if (state == LEADING_EDGE || state == TRAILING_EDGE)
            mosi = tx_shift[7];
        else
            mosi = 1'b0;
    end

endmodule
