// UART Transmitter with Baud Rate Generator
// Demonstrates: Generated clocks, multicycle paths

module uart_tx #(
    parameter CLK_FREQ  = 50_000_000,
    parameter BAUD_RATE = 115_200
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire [7:0] tx_data,
    input  wire       tx_valid,
    output reg        tx_out,
    output wire       tx_busy
);

    localparam BAUD_DIV = CLK_FREQ / BAUD_RATE;
    localparam DIV_W    = $clog2(BAUD_DIV);

    reg [DIV_W-1:0] baud_counter;
    wire             baud_tick;

    reg [3:0] bit_counter;
    reg [9:0] shift_reg;
    reg       active;

    assign baud_tick = (baud_counter == BAUD_DIV - 1);
    assign tx_busy   = active;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            baud_counter <= {DIV_W{1'b0}};
        end else if (active) begin
            if (baud_tick)
                baud_counter <= {DIV_W{1'b0}};
            else
                baud_counter <= baud_counter + 1'b1;
        end else begin
            baud_counter <= {DIV_W{1'b0}};
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            active      <= 1'b0;
            bit_counter <= 4'd0;
            shift_reg   <= 10'h3FF;
            tx_out      <= 1'b1;
        end else if (!active && tx_valid) begin
            active      <= 1'b1;
            bit_counter <= 4'd0;
            shift_reg   <= {1'b1, tx_data, 1'b0};
            tx_out      <= 1'b0;
        end else if (active && baud_tick) begin
            if (bit_counter == 4'd9) begin
                active  <= 1'b0;
                tx_out  <= 1'b1;
            end else begin
                bit_counter <= bit_counter + 1'b1;
                tx_out      <= shift_reg[1];
                shift_reg   <= {1'b1, shift_reg[9:1]};
            end
        end
    end

endmodule
