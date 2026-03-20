// Asynchronous FIFO (Dual-Clock FIFO)
// Safely transfers data between two independent clock domains.
// Uses Gray-coded pointers for CDC to avoid multi-bit glitches.
// Based on Clifford Cummings' proven architecture (SNUG 2002).

module async_fifo #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 4     // FIFO depth = 2^ADDR_WIDTH
)(
    // Write clock domain
    input  logic                    wr_clk,
    input  logic                    wr_rst_n,
    input  logic                    wr_en,
    input  logic [DATA_WIDTH-1:0]   wr_data,
    output logic                    full,
    // Read clock domain
    input  logic                    rd_clk,
    input  logic                    rd_rst_n,
    input  logic                    rd_en,
    output logic [DATA_WIDTH-1:0]   rd_data,
    output logic                    empty
);

    localparam DEPTH = 2**ADDR_WIDTH;

    // Dual-port memory
    logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    // Binary and Gray-coded pointers
    logic [ADDR_WIDTH:0] wr_bin, wr_bin_next;
    logic [ADDR_WIDTH:0] wr_gray, wr_gray_next;
    logic [ADDR_WIDTH:0] rd_bin, rd_bin_next;
    logic [ADDR_WIDTH:0] rd_gray, rd_gray_next;

    // Synchronized pointers (crossed between domains)
    logic [ADDR_WIDTH:0] wr_gray_sync2;  // wr_gray synchronized to rd_clk
    logic [ADDR_WIDTH:0] rd_gray_sync2;  // rd_gray synchronized to wr_clk

    // Synchronizer for write-to-read crossing
    (* async_reg = "true" *)
    logic [ADDR_WIDTH:0] wr_gray_sync1;

    always_ff @(posedge rd_clk or negedge rd_rst_n) begin
        if (!rd_rst_n) begin
            wr_gray_sync1 <= '0;
            wr_gray_sync2 <= '0;
        end else begin
            wr_gray_sync1 <= wr_gray;
            wr_gray_sync2 <= wr_gray_sync1;
        end
    end

    // Synchronizer for read-to-write crossing
    (* async_reg = "true" *)
    logic [ADDR_WIDTH:0] rd_gray_sync1;

    always_ff @(posedge wr_clk or negedge wr_rst_n) begin
        if (!wr_rst_n) begin
            rd_gray_sync1 <= '0;
            rd_gray_sync2 <= '0;
        end else begin
            rd_gray_sync1 <= rd_gray;
            rd_gray_sync2 <= rd_gray_sync1;
        end
    end

    // Binary-to-Gray conversion
    assign wr_gray_next = (wr_bin_next >> 1) ^ wr_bin_next;
    assign rd_gray_next = (rd_bin_next >> 1) ^ rd_bin_next;

    // Write pointer logic
    assign wr_bin_next = wr_bin + (wr_en & ~full);

    always_ff @(posedge wr_clk or negedge wr_rst_n) begin
        if (!wr_rst_n) begin
            wr_bin  <= '0;
            wr_gray <= '0;
        end else begin
            wr_bin  <= wr_bin_next;
            wr_gray <= wr_gray_next;
        end
    end

    // Read pointer logic
    assign rd_bin_next = rd_bin + (rd_en & ~empty);

    always_ff @(posedge rd_clk or negedge rd_rst_n) begin
        if (!rd_rst_n) begin
            rd_bin  <= '0;
            rd_gray <= '0;
        end else begin
            rd_bin  <= rd_bin_next;
            rd_gray <= rd_gray_next;
        end
    end

    // Memory write
    always_ff @(posedge wr_clk) begin
        if (wr_en && !full)
            mem[wr_bin[ADDR_WIDTH-1:0]] <= wr_data;
    end

    // Memory read (combinational for FWFT behavior)
    assign rd_data = mem[rd_bin[ADDR_WIDTH-1:0]];

    // Full flag: MSBs differ, rest equal (in Gray code)
    assign full = (wr_gray_next == {~rd_gray_sync2[ADDR_WIDTH:ADDR_WIDTH-1],
                                      rd_gray_sync2[ADDR_WIDTH-2:0]});

    // Empty flag: Gray-coded pointers match
    assign empty = (rd_gray_next == wr_gray_sync2);

endmodule
