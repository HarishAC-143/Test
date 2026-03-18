// =============================================================================
// SPI Master Controller
// Demonstrates: Serial protocol implementation, clock generation, shift registers
// Supports: CPOL/CPHA configuration (all 4 SPI modes)
// =============================================================================

module spi_master #(
    parameter int DATA_WIDTH  = 8,
    parameter int CLK_DIV     = 4   // SPI clock = sys_clk / (2 * CLK_DIV)
) (
    input  logic                  clk,
    input  logic                  rst_n,

    // Control interface
    input  logic                  start,
    input  logic [DATA_WIDTH-1:0] tx_data,
    output logic [DATA_WIDTH-1:0] rx_data,
    output logic                  busy,
    output logic                  done,
    input  logic                  cpol,       // Clock polarity
    input  logic                  cpha,       // Clock phase

    // SPI signals
    output logic                  sclk,
    output logic                  mosi,
    input  logic                  miso,
    output logic                  cs_n
);

    typedef enum logic [2:0] {
        IDLE,
        LOAD,
        TRANSFER,
        CAPTURE,
        COMPLETE
    } state_e;

    state_e state;

    logic [$clog2(CLK_DIV)-1:0] clk_counter;
    logic [$clog2(DATA_WIDTH)-1:0] bit_counter;
    logic [DATA_WIDTH-1:0] shift_reg_tx;
    logic [DATA_WIDTH-1:0] shift_reg_rx;
    logic                  sclk_int;
    logic                  sclk_edge;
    logic                  sample_edge;
    logic                  shift_edge;

    // Clock divider
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            clk_counter <= '0;
            sclk_int    <= 1'b0;
            sclk_edge   <= 1'b0;
        end else if (state == TRANSFER || state == CAPTURE) begin
            sclk_edge <= 1'b0;
            if (clk_counter == CLK_DIV - 1) begin
                clk_counter <= '0;
                sclk_int    <= ~sclk_int;
                sclk_edge   <= 1'b1;
            end else begin
                clk_counter <= clk_counter + 1'b1;
            end
        end else begin
            clk_counter <= '0;
            sclk_int    <= 1'b0;
            sclk_edge   <= 1'b0;
        end
    end

    // CPOL: idle polarity; CPHA: which edge samples data
    assign sclk = sclk_int ^ cpol;
    assign sample_edge = sclk_edge && (sclk_int == cpha);
    assign shift_edge  = sclk_edge && (sclk_int != cpha);

    // Main FSM
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state        <= IDLE;
            shift_reg_tx <= '0;
            shift_reg_rx <= '0;
            bit_counter  <= '0;
            cs_n         <= 1'b1;
            mosi         <= 1'b0;
            busy         <= 1'b0;
            done         <= 1'b0;
            rx_data      <= '0;
        end else begin
            done <= 1'b0;

            unique case (state)
                IDLE: begin
                    cs_n <= 1'b1;
                    busy <= 1'b0;
                    if (start) begin
                        shift_reg_tx <= tx_data;
                        bit_counter  <= '0;
                        busy         <= 1'b1;
                        state        <= LOAD;
                    end
                end

                LOAD: begin
                    cs_n <= 1'b0;
                    mosi <= shift_reg_tx[DATA_WIDTH-1]; // MSB first
                    state <= TRANSFER;
                end

                TRANSFER: begin
                    if (sample_edge) begin
                        shift_reg_rx <= {shift_reg_rx[DATA_WIDTH-2:0], miso};
                        state <= CAPTURE;
                    end
                end

                CAPTURE: begin
                    if (shift_edge) begin
                        if (bit_counter == DATA_WIDTH - 1) begin
                            state <= COMPLETE;
                        end else begin
                            bit_counter  <= bit_counter + 1'b1;
                            shift_reg_tx <= {shift_reg_tx[DATA_WIDTH-2:0], 1'b0};
                            mosi         <= shift_reg_tx[DATA_WIDTH-2];
                            state        <= TRANSFER;
                        end
                    end
                end

                COMPLETE: begin
                    cs_n    <= 1'b1;
                    rx_data <= shift_reg_rx;
                    done    <= 1'b1;
                    state   <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
