// UART Receiver with Oversampling
// Demonstrates: Input sampling, synchronous design

module uart_rx #(
    parameter CLK_FREQ  = 50_000_000,
    parameter BAUD_RATE = 115_200
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       rx_in,
    output reg  [7:0] rx_data,
    output reg        rx_valid
);

    localparam BAUD_DIV = CLK_FREQ / BAUD_RATE;
    localparam HALF_DIV = BAUD_DIV / 2;
    localparam DIV_W    = $clog2(BAUD_DIV);

    reg [DIV_W-1:0] baud_counter;
    reg [3:0]       bit_counter;
    reg [7:0]       shift_reg;
    reg              active;

    reg rx_sync_0, rx_sync_1;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_sync_0 <= 1'b1;
            rx_sync_1 <= 1'b1;
        end else begin
            rx_sync_0 <= rx_in;
            rx_sync_1 <= rx_sync_0;
        end
    end

    wire rx_filtered = rx_sync_1;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            active       <= 1'b0;
            baud_counter <= {DIV_W{1'b0}};
            bit_counter  <= 4'd0;
            shift_reg    <= 8'd0;
            rx_data      <= 8'd0;
            rx_valid     <= 1'b0;
        end else begin
            rx_valid <= 1'b0;

            if (!active) begin
                if (!rx_filtered) begin
                    active       <= 1'b1;
                    baud_counter <= {DIV_W{1'b0}};
                    bit_counter  <= 4'd0;
                end
            end else begin
                if (baud_counter == (bit_counter == 0 ? HALF_DIV - 1 : BAUD_DIV - 1)) begin
                    baud_counter <= {DIV_W{1'b0}};

                    if (bit_counter == 0) begin
                        if (rx_filtered) begin
                            active <= 1'b0;
                        end else begin
                            bit_counter <= 4'd1;
                        end
                    end else if (bit_counter <= 4'd8) begin
                        shift_reg   <= {rx_filtered, shift_reg[7:1]};
                        bit_counter <= bit_counter + 1'b1;
                    end else begin
                        if (rx_filtered) begin
                            rx_data  <= shift_reg;
                            rx_valid <= 1'b1;
                        end
                        active <= 1'b0;
                    end
                end else begin
                    baud_counter <= baud_counter + 1'b1;
                end
            end
        end
    end

endmodule
