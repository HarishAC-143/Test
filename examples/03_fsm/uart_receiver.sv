// UART Receiver FSM
// 8N1 format: 1 start bit, 8 data bits, no parity, 1 stop bit

module uart_receiver #(
    parameter CLK_FREQ  = 50_000_000,
    parameter BAUD_RATE = 115200
)(
    input  logic       clk,
    input  logic       rst_n,
    input  logic       rx,
    output logic [7:0] data_out,
    output logic       data_valid,
    output logic       frame_error
);

    localparam CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;

    typedef enum logic [2:0] {
        IDLE,
        START_BIT,
        DATA_BITS,
        STOP_BIT,
        DONE
    } state_e;

    state_e state, next_state;

    logic [$clog2(CLKS_PER_BIT)-1:0] clk_count;
    logic [2:0]                       bit_index;
    logic [7:0]                       rx_shift;
    logic                             rx_sync_0, rx_sync_1;

    // Double-register the input to avoid metastability
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_sync_0 <= 1'b1;
            rx_sync_1 <= 1'b1;
        end else begin
            rx_sync_0 <= rx;
            rx_sync_1 <= rx_sync_0;
        end
    end

    // State register
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= IDLE;
        else
            state <= next_state;
    end

    // Next-state and datapath logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            clk_count   <= '0;
            bit_index   <= '0;
            rx_shift    <= '0;
            data_out    <= '0;
            data_valid  <= 1'b0;
            frame_error <= 1'b0;
        end else begin
            data_valid  <= 1'b0;
            frame_error <= 1'b0;

            case (state)
                IDLE: begin
                    clk_count <= '0;
                    bit_index <= '0;
                end

                START_BIT: begin
                    if (clk_count == CLKS_PER_BIT / 2)
                        clk_count <= '0;
                    else
                        clk_count <= clk_count + 1'b1;
                end

                DATA_BITS: begin
                    if (clk_count == CLKS_PER_BIT - 1) begin
                        clk_count <= '0;
                        rx_shift  <= {rx_sync_1, rx_shift[7:1]};
                        bit_index <= bit_index + 1'b1;
                    end else begin
                        clk_count <= clk_count + 1'b1;
                    end
                end

                STOP_BIT: begin
                    if (clk_count == CLKS_PER_BIT - 1) begin
                        clk_count <= '0;
                        data_out  <= rx_shift;
                        data_valid <= 1'b1;
                        if (!rx_sync_1)
                            frame_error <= 1'b1;
                    end else begin
                        clk_count <= clk_count + 1'b1;
                    end
                end

                default: ;
            endcase
        end
    end

    // Next-state combinational logic
    always_comb begin
        next_state = state;

        case (state)
            IDLE:
                if (!rx_sync_1)
                    next_state = START_BIT;

            START_BIT:
                if (clk_count == CLKS_PER_BIT / 2) begin
                    if (!rx_sync_1)
                        next_state = DATA_BITS;
                    else
                        next_state = IDLE;
                end

            DATA_BITS:
                if (clk_count == CLKS_PER_BIT - 1 && bit_index == 3'd7)
                    next_state = STOP_BIT;

            STOP_BIT:
                if (clk_count == CLKS_PER_BIT - 1)
                    next_state = DONE;

            DONE:
                next_state = IDLE;

            default: next_state = IDLE;
        endcase
    end

endmodule
