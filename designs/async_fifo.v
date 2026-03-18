// ============================================================
// Async FIFO - Gray-coded pointer, dual-clock FIFO
// ============================================================
// Used in the data_processor design for ADC clock domain crossing.
// Demonstrates the RTL structure that the CDC SDC constraints target.
// ============================================================

module async_fifo #(
    parameter DATA_WIDTH = 12,
    parameter ADDR_WIDTH = 4
) (
    // Write port
    input  wire                  wr_clk,
    input  wire                  wr_rst_n,
    input  wire                  wr_en,
    input  wire [DATA_WIDTH-1:0] wr_data,
    output wire                  full,

    // Read port
    input  wire                  rd_clk,
    input  wire                  rd_rst_n,
    input  wire                  rd_en,
    output wire [DATA_WIDTH-1:0] rd_data,
    output wire                  empty
);

    localparam DEPTH = 1 << ADDR_WIDTH;

    // Dual-port RAM
    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    // Write pointer (binary and gray)
    reg [ADDR_WIDTH:0] wr_ptr;
    reg [ADDR_WIDTH:0] wr_ptr_gray;

    // Read pointer (binary and gray)
    reg [ADDR_WIDTH:0] rd_ptr;
    reg [ADDR_WIDTH:0] rd_ptr_gray;

    // Synchronized pointers (the CDC registers targeted by SDC constraints)
    // rd_sync_ff1/ff2: wr_ptr_gray synchronized into rd_clk domain
    reg [ADDR_WIDTH:0] rd_sync_ff1;
    reg [ADDR_WIDTH:0] rd_sync_ff2;

    // wr_sync_ff1/ff2: rd_ptr_gray synchronized into wr_clk domain
    reg [ADDR_WIDTH:0] wr_sync_ff1;
    reg [ADDR_WIDTH:0] wr_sync_ff2;

    // Binary to gray conversion
    function [ADDR_WIDTH:0] bin2gray;
        input [ADDR_WIDTH:0] bin;
        bin2gray = bin ^ (bin >> 1);
    endfunction

    // ========================================================
    // Write Logic (wr_clk domain)
    // ========================================================
    always @(posedge wr_clk or negedge wr_rst_n) begin
        if (!wr_rst_n) begin
            wr_ptr      <= 0;
            wr_ptr_gray <= 0;
        end else if (wr_en && !full) begin
            wr_ptr      <= wr_ptr + 1;
            wr_ptr_gray <= bin2gray(wr_ptr + 1);
        end
    end

    always @(posedge wr_clk) begin
        if (wr_en && !full)
            mem[wr_ptr[ADDR_WIDTH-1:0]] <= wr_data;
    end

    // ========================================================
    // Read Logic (rd_clk domain)
    // ========================================================
    always @(posedge rd_clk or negedge rd_rst_n) begin
        if (!rd_rst_n) begin
            rd_ptr      <= 0;
            rd_ptr_gray <= 0;
        end else if (rd_en && !empty) begin
            rd_ptr      <= rd_ptr + 1;
            rd_ptr_gray <= bin2gray(rd_ptr + 1);
        end
    end

    assign rd_data = mem[rd_ptr[ADDR_WIDTH-1:0]];

    // ========================================================
    // CDC Synchronizers
    // ========================================================
    // These are the double-FF synchronizers targeted by:
    //   set_max_delay ... -from wr_ptr_gray -to rd_sync_ff1
    //   set_max_delay ... -from rd_ptr_gray -to wr_sync_ff1

    // Synchronize wr_ptr_gray into rd_clk domain
    always @(posedge rd_clk or negedge rd_rst_n) begin
        if (!rd_rst_n) begin
            rd_sync_ff1 <= 0;
            rd_sync_ff2 <= 0;
        end else begin
            rd_sync_ff1 <= wr_ptr_gray;
            rd_sync_ff2 <= rd_sync_ff1;
        end
    end

    // Synchronize rd_ptr_gray into wr_clk domain
    always @(posedge wr_clk or negedge wr_rst_n) begin
        if (!wr_rst_n) begin
            wr_sync_ff1 <= 0;
            wr_sync_ff2 <= 0;
        end else begin
            wr_sync_ff1 <= rd_ptr_gray;
            wr_sync_ff2 <= wr_sync_ff1;
        end
    end

    // ========================================================
    // Status Flags
    // ========================================================
    assign full  = (wr_ptr_gray == {~rd_sync_ff2[ADDR_WIDTH:ADDR_WIDTH-1],
                                     rd_sync_ff2[ADDR_WIDTH-2:0]});
    assign empty = (rd_ptr_gray == wr_sync_ff2);

endmodule
