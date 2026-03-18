// =============================================================================
// SPI Master Controller
// Supports all 4 SPI modes (CPOL/CPHA combinations).
// Configurable clock divider and data width.
// =============================================================================

module spi_master #(
    parameter DATA_WIDTH = 8,
    parameter CLK_DIV    = 4    // SCLK = clk / (2 * CLK_DIV)
) (
    input  logic                    clk,
    input  logic                    rst_n,

    // Control
    input  logic                    start,
    input  logic                    cpol,         // Clock polarity
    input  logic                    cpha,         // Clock phase
    input  logic [DATA_WIDTH-1:0]   mosi_data,
    output logic [DATA_WIDTH-1:0]   miso_data,
    output logic                    busy,
    output logic                    done,

    // SPI signals
    output logic                    sclk,
    output logic                    mosi,
    input  logic                    miso,
    output logic                    cs_n
);

    typedef enum logic [2:0] {
        IDLE    = 3'b000,
        LEADING = 3'b001,    // Leading edge of SCLK
        TRAILING = 3'b010,   // Trailing edge of SCLK
        DONE_ST = 3'b011
    } state_e;

    state_e state;
    logic [$clog2(CLK_DIV)-1:0] clk_counter;
    logic [$clog2(DATA_WIDTH)-1:0] bit_counter;
    logic [DATA_WIDTH-1:0] shift_reg_tx;
    logic [DATA_WIDTH-1:0] shift_reg_rx;
    logic sclk_internal;
    logic sample_edge, shift_edge;

    assign busy = (state != IDLE);

    // Determine sample and shift edges based on CPHA
    // CPHA=0: sample on leading edge, shift on trailing edge
    // CPHA=1: shift on leading edge, sample on trailing edge
    assign sample_edge = cpha ? (state == TRAILING) : (state == LEADING);
    assign shift_edge  = cpha ? (state == LEADING)  : (state == TRAILING);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state        <= IDLE;
            sclk_internal <= 1'b0;
            cs_n         <= 1'b1;
            mosi         <= 1'b0;
            shift_reg_tx <= '0;
            shift_reg_rx <= '0;
            miso_data    <= '0;
            clk_counter  <= '0;
            bit_counter  <= '0;
            done         <= 1'b0;
        end else begin
            done <= 1'b0;

            case (state)
                IDLE: begin
                    sclk_internal <= cpol;
                    cs_n          <= 1'b1;
                    if (start) begin
                        shift_reg_tx <= mosi_data;
                        shift_reg_rx <= '0;
                        bit_counter  <= '0;
                        clk_counter  <= '0;
                        cs_n         <= 1'b0;
                        state        <= cpha ? LEADING : LEADING;
                        mosi         <= mosi_data[DATA_WIDTH-1];
                    end
                end

                LEADING: begin
                    if (clk_counter == CLK_DIV[$clog2(CLK_DIV)-1:0] - 1) begin
                        clk_counter   <= '0;
                        sclk_internal <= ~sclk_internal;

                        if (!cpha) begin
                            // Sample MISO
                            shift_reg_rx <= {shift_reg_rx[DATA_WIDTH-2:0], miso};
                        end else begin
                            // Shift MOSI
                            shift_reg_tx <= {shift_reg_tx[DATA_WIDTH-2:0], 1'b0};
                            mosi         <= shift_reg_tx[DATA_WIDTH-2];
                        end

                        state <= TRAILING;
                    end else begin
                        clk_counter <= clk_counter + 1'b1;
                    end
                end

                TRAILING: begin
                    if (clk_counter == CLK_DIV[$clog2(CLK_DIV)-1:0] - 1) begin
                        clk_counter   <= '0;
                        sclk_internal <= ~sclk_internal;

                        if (cpha) begin
                            // Sample MISO
                            shift_reg_rx <= {shift_reg_rx[DATA_WIDTH-2:0], miso};
                        end else begin
                            // Shift MOSI
                            shift_reg_tx <= {shift_reg_tx[DATA_WIDTH-2:0], 1'b0};
                            mosi         <= shift_reg_tx[DATA_WIDTH-2];
                        end

                        if (bit_counter == DATA_WIDTH[$clog2(DATA_WIDTH)-1:0] - 1) begin
                            state <= DONE_ST;
                        end else begin
                            bit_counter <= bit_counter + 1'b1;
                            state       <= LEADING;
                        end
                    end else begin
                        clk_counter <= clk_counter + 1'b1;
                    end
                end

                DONE_ST: begin
                    cs_n          <= 1'b1;
                    sclk_internal <= cpol;
                    miso_data     <= shift_reg_rx;
                    done          <= 1'b1;
                    state         <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

    assign sclk = sclk_internal;

endmodule
