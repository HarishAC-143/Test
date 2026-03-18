// SPI Master Controller
// Supports all 4 SPI modes (CPOL/CPHA), configurable clock divider,
// and variable transaction width up to 32 bits.

module spi_master #(
    parameter int CLK_DIV   = 4,     // SCLK = clk / (2 * CLK_DIV)
    parameter int MAX_WIDTH = 8      // Maximum bits per transaction
) (
    input  logic                   clk,
    input  logic                   rst_n,

    // Control interface
    input  logic                   start,
    input  logic [1:0]             mode,        // {CPOL, CPHA}
    input  logic [$clog2(MAX_WIDTH)-1:0] bit_count,  // Number of bits - 1
    input  logic [MAX_WIDTH-1:0]   tx_data,     // Data to transmit (MSB first)
    output logic [MAX_WIDTH-1:0]   rx_data,     // Received data
    output logic                   busy,
    output logic                   done,

    // SPI signals
    output logic                   sclk,
    output logic                   mosi,
    input  logic                   miso,
    output logic                   cs_n
);

    localparam int DIV_W = $clog2(CLK_DIV + 1);
    localparam int BIT_W = $clog2(MAX_WIDTH);

    logic cpol, cpha;
    assign cpol = mode[1];
    assign cpha = mode[0];

    typedef enum logic [2:0] {
        S_IDLE,
        S_ASSERT_CS,
        S_LEADING_EDGE,
        S_TRAILING_EDGE,
        S_DEASSERT_CS
    } state_t;

    state_t state;

    logic [DIV_W-1:0]       div_counter;
    logic                   div_tick;
    logic [BIT_W-1:0]       bit_counter;
    logic [BIT_W-1:0]       bit_max;
    logic [MAX_WIDTH-1:0]   shift_out;
    logic [MAX_WIDTH-1:0]   shift_in;
    logic                   sclk_reg;

    assign div_tick = (div_counter == CLK_DIV - 1);

    // Clock divider
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            div_counter <= '0;
        end else if (state == S_IDLE) begin
            div_counter <= '0;
        end else if (div_tick) begin
            div_counter <= '0;
        end else begin
            div_counter <= div_counter + 1;
        end
    end

    // Main state machine
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state       <= S_IDLE;
            sclk_reg    <= 1'b0;
            mosi        <= 1'b0;
            cs_n        <= 1'b1;
            busy        <= 1'b0;
            done        <= 1'b0;
            shift_out   <= '0;
            shift_in    <= '0;
            bit_counter <= '0;
            bit_max     <= '0;
            rx_data     <= '0;
        end else begin
            done <= 1'b0;

            unique case (state)
                S_IDLE: begin
                    sclk_reg <= cpol;  // Idle polarity
                    cs_n     <= 1'b1;
                    if (start) begin
                        state     <= S_ASSERT_CS;
                        shift_out <= tx_data;
                        shift_in  <= '0;
                        bit_counter <= '0;
                        bit_max   <= bit_count;
                        busy      <= 1'b1;
                    end
                end

                S_ASSERT_CS: begin
                    cs_n <= 1'b0;
                    sclk_reg <= cpol;

                    // In CPHA=0 mode, data is set up before first clock edge
                    if (!cpha)
                        mosi <= shift_out[MAX_WIDTH-1];

                    if (div_tick)
                        state <= S_LEADING_EDGE;
                end

                S_LEADING_EDGE: begin
                    if (div_tick) begin
                        sclk_reg <= ~sclk_reg;

                        if (cpha) begin
                            // CPHA=1: data changes on leading edge
                            mosi <= shift_out[MAX_WIDTH-1];
                        end else begin
                            // CPHA=0: data sampled on leading edge
                            shift_in <= {shift_in[MAX_WIDTH-2:0], miso};
                        end

                        state <= S_TRAILING_EDGE;
                    end
                end

                S_TRAILING_EDGE: begin
                    if (div_tick) begin
                        sclk_reg <= ~sclk_reg;

                        if (cpha) begin
                            // CPHA=1: data sampled on trailing edge
                            shift_in <= {shift_in[MAX_WIDTH-2:0], miso};
                        end else begin
                            // CPHA=0: data changes on trailing edge
                            // (prepare next bit)
                        end

                        shift_out <= {shift_out[MAX_WIDTH-2:0], 1'b0};

                        if (bit_counter == bit_max) begin
                            state <= S_DEASSERT_CS;
                        end else begin
                            bit_counter <= bit_counter + 1;

                            if (!cpha)
                                mosi <= shift_out[MAX_WIDTH-2];

                            state <= S_LEADING_EDGE;
                        end
                    end
                end

                S_DEASSERT_CS: begin
                    if (div_tick) begin
                        cs_n     <= 1'b1;
                        sclk_reg <= cpol;
                        rx_data  <= shift_in;
                        busy     <= 1'b0;
                        done     <= 1'b1;
                        state    <= S_IDLE;
                    end
                end
            endcase
        end
    end

    assign sclk = sclk_reg;

endmodule
