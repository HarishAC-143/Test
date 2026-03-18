// DDR I/O Interface
// Demonstrates: Source-synchronous DDR constraints

module ddr_io #(
    parameter DATA_WIDTH = 8
)(
    input  wire                    sys_clk,
    input  wire                    rst_n,

    // DDR TX interface
    input  wire [DATA_WIDTH-1:0]   tx_data_rise,
    input  wire [DATA_WIDTH-1:0]   tx_data_fall,
    input  wire                    tx_valid,
    output reg  [DATA_WIDTH-1:0]   ddr_dq_out,
    output reg                     ddr_clk_out,

    // DDR RX interface
    input  wire                    ddr_clk_in,
    input  wire [DATA_WIDTH-1:0]   ddr_dq_in,
    output reg  [DATA_WIDTH-1:0]   rx_data_rise,
    output reg  [DATA_WIDTH-1:0]   rx_data_fall,
    output reg                     rx_valid
);

    // TX: Output DDR data using both clock edges
    reg phase;

    always @(posedge sys_clk or negedge rst_n) begin
        if (!rst_n) begin
            ddr_dq_out  <= {DATA_WIDTH{1'b0}};
            ddr_clk_out <= 1'b0;
            phase       <= 1'b0;
        end else if (tx_valid) begin
            if (!phase) begin
                ddr_dq_out  <= tx_data_rise;
                ddr_clk_out <= 1'b1;
                phase       <= 1'b1;
            end else begin
                ddr_dq_out  <= tx_data_fall;
                ddr_clk_out <= 1'b0;
                phase       <= 1'b0;
            end
        end
    end

    // RX: Capture DDR data on both edges of incoming clock
    reg [DATA_WIDTH-1:0] rise_capture;
    reg [DATA_WIDTH-1:0] fall_capture;

    always @(posedge ddr_clk_in or negedge rst_n) begin
        if (!rst_n)
            rise_capture <= {DATA_WIDTH{1'b0}};
        else
            rise_capture <= ddr_dq_in;
    end

    always @(negedge ddr_clk_in or negedge rst_n) begin
        if (!rst_n)
            fall_capture <= {DATA_WIDTH{1'b0}};
        else
            fall_capture <= ddr_dq_in;
    end

    // Transfer to sys_clk domain
    always @(posedge sys_clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_data_rise <= {DATA_WIDTH{1'b0}};
            rx_data_fall <= {DATA_WIDTH{1'b0}};
            rx_valid     <= 1'b0;
        end else begin
            rx_data_rise <= rise_capture;
            rx_data_fall <= fall_capture;
            rx_valid     <= 1'b1;
        end
    end

endmodule
