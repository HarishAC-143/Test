// ----------------------------------------------------------------------------
// Advanced FSM: SPI Master Controller
// Demonstrates: Mealy/Moore hybrid, one-hot encoding, state coverage,
//               multi-cycle operations, parameterized bit-width
// ----------------------------------------------------------------------------

module spi_master_controller #(
    parameter int DATA_WIDTH  = 8,
    parameter int CLK_DIV     = 4,    // SPI clock = sys_clk / (2 * CLK_DIV)
    parameter int CS_SETUP    = 2,    // CS setup cycles before first clock edge
    parameter int CS_HOLD     = 2     // CS hold cycles after last clock edge
)(
    input  logic                    clk,
    input  logic                    rst_n,

    // Control interface
    input  logic                    start,
    input  logic [DATA_WIDTH-1:0]   tx_data,
    output logic [DATA_WIDTH-1:0]   rx_data,
    output logic                    busy,
    output logic                    done,

    // SPI signals
    output logic                    spi_clk,
    output logic                    spi_mosi,
    input  logic                    spi_miso,
    output logic                    spi_cs_n
);

    localparam int BIT_CNT_WIDTH = $clog2(DATA_WIDTH);
    localparam int DIV_CNT_WIDTH = $clog2(CLK_DIV);

    // One-hot encoded states for faster decode in silicon
    typedef enum logic [4:0] {
        S_IDLE     = 5'b00001,
        S_CS_SETUP = 5'b00010,
        S_TRANSFER = 5'b00100,
        S_CS_HOLD  = 5'b01000,
        S_DONE     = 5'b10000
    } spi_state_t;

    spi_state_t state, next_state;

    logic [DIV_CNT_WIDTH-1:0]  clk_div_cnt;
    logic [BIT_CNT_WIDTH-1:0]  bit_cnt;
    logic [$clog2(CS_SETUP):0] setup_cnt;
    logic [$clog2(CS_HOLD):0]  hold_cnt;
    logic [DATA_WIDTH-1:0]     shift_reg_tx;
    logic [DATA_WIDTH-1:0]     shift_reg_rx;
    logic                      spi_clk_int;
    logic                      clk_edge;
    logic                      clk_rising;
    logic                      clk_falling;

    // Clock divider for SPI clock generation
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            clk_div_cnt <= '0;
            spi_clk_int <= 1'b0;
        end else if (state == S_TRANSFER) begin
            if (clk_div_cnt == CLK_DIV - 1) begin
                clk_div_cnt <= '0;
                spi_clk_int <= ~spi_clk_int;
            end else begin
                clk_div_cnt <= clk_div_cnt + 1'b1;
            end
        end else begin
            clk_div_cnt <= '0;
            spi_clk_int <= 1'b0;
        end
    end

    assign clk_edge   = (clk_div_cnt == CLK_DIV - 1);
    assign clk_rising  = clk_edge && !spi_clk_int;
    assign clk_falling = clk_edge &&  spi_clk_int;

    // FSM next-state logic (combinational)
    always_comb begin
        next_state = state;

        case (state)
            S_IDLE: begin
                if (start)
                    next_state = S_CS_SETUP;
            end

            S_CS_SETUP: begin
                if (setup_cnt == CS_SETUP - 1)
                    next_state = S_TRANSFER;
            end

            S_TRANSFER: begin
                if (clk_falling && bit_cnt == DATA_WIDTH - 1)
                    next_state = S_CS_HOLD;
            end

            S_CS_HOLD: begin
                if (hold_cnt == CS_HOLD - 1)
                    next_state = S_DONE;
            end

            S_DONE: begin
                next_state = S_IDLE;
            end

            default: next_state = S_IDLE;
        endcase
    end

    // FSM state register
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= S_IDLE;
        else
            state <= next_state;
    end

    // Datapath: shift registers, counters, outputs
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            shift_reg_tx <= '0;
            shift_reg_rx <= '0;
            bit_cnt      <= '0;
            setup_cnt    <= '0;
            hold_cnt     <= '0;
            rx_data      <= '0;
        end else begin
            case (state)
                S_IDLE: begin
                    bit_cnt   <= '0;
                    setup_cnt <= '0;
                    hold_cnt  <= '0;
                    if (start)
                        shift_reg_tx <= tx_data;
                end

                S_CS_SETUP: begin
                    setup_cnt <= setup_cnt + 1'b1;
                end

                S_TRANSFER: begin
                    if (clk_rising) begin
                        // Sample MISO on rising edge
                        shift_reg_rx <= {shift_reg_rx[DATA_WIDTH-2:0], spi_miso};
                    end
                    if (clk_falling) begin
                        // Shift out MOSI on falling edge
                        shift_reg_tx <= {shift_reg_tx[DATA_WIDTH-2:0], 1'b0};
                        bit_cnt      <= bit_cnt + 1'b1;
                    end
                end

                S_CS_HOLD: begin
                    hold_cnt <= hold_cnt + 1'b1;
                end

                S_DONE: begin
                    rx_data <= shift_reg_rx;
                end

                default: ;
            endcase
        end
    end

    // Output assignments
    assign spi_clk  = (state == S_TRANSFER) ? spi_clk_int : 1'b0;
    assign spi_mosi = shift_reg_tx[DATA_WIDTH-1];
    assign spi_cs_n = (state == S_IDLE || state == S_DONE);
    assign busy     = (state != S_IDLE);
    assign done     = (state == S_DONE);

endmodule
