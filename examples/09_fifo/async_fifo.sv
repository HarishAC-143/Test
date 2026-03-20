// Asynchronous FIFO (Dual-Clock FIFO)
// Safely transfers data between two unrelated clock domains.
// Uses Gray code pointers for safe CDC of the read/write pointers.
// Based on Clifford Cummings' well-known async FIFO design (SNUG 2002).

module async_fifo #(
    parameter int DATA_WIDTH = 8,
    parameter int DEPTH      = 16,
    parameter int ADDR_WIDTH = $clog2(DEPTH)
) (
    // Write clock domain
    input  logic                  wr_clk,
    input  logic                  wr_rst_n,
    input  logic                  wr_en,
    input  logic [DATA_WIDTH-1:0] wr_data,
    output logic                  wr_full,

    // Read clock domain
    input  logic                  rd_clk,
    input  logic                  rd_rst_n,
    input  logic                  rd_en,
    output logic [DATA_WIDTH-1:0] rd_data,
    output logic                  rd_empty
);

    // Dual-port RAM
    logic [DATA_WIDTH-1:0] mem [DEPTH];

    // Binary and Gray code pointers
    logic [ADDR_WIDTH:0] wr_bin, wr_gray, wr_bin_next, wr_gray_next;
    logic [ADDR_WIDTH:0] rd_bin, rd_gray, rd_bin_next, rd_gray_next;

    // Synchronized Gray code pointers (crossed clock domains)
    logic [ADDR_WIDTH:0] wr_gray_sync1, wr_gray_sync2;  // wr_gray in rd domain
    logic [ADDR_WIDTH:0] rd_gray_sync1, rd_gray_sync2;  // rd_gray in wr domain

    // =========================================================================
    // Write Logic (wr_clk domain)
    // =========================================================================
    wire wr_valid = wr_en && !wr_full;

    assign wr_bin_next  = wr_bin + wr_valid;
    assign wr_gray_next = wr_bin_next ^ (wr_bin_next >> 1);

    always_ff @(posedge wr_clk or negedge wr_rst_n) begin
        if (!wr_rst_n) begin
            wr_bin  <= '0;
            wr_gray <= '0;
        end else begin
            wr_bin  <= wr_bin_next;
            wr_gray <= wr_gray_next;
        end
    end

    always_ff @(posedge wr_clk) begin
        if (wr_valid)
            mem[wr_bin[ADDR_WIDTH-1:0]] <= wr_data;
    end

    // Synchronize rd_gray into wr_clk domain (2-FF synchronizer)
    always_ff @(posedge wr_clk or negedge wr_rst_n) begin
        if (!wr_rst_n) begin
            rd_gray_sync1 <= '0;
            rd_gray_sync2 <= '0;
        end else begin
            rd_gray_sync1 <= rd_gray;
            rd_gray_sync2 <= rd_gray_sync1;
        end
    end

    // Full when write Gray code equals inverted MSBs of synced read Gray code
    assign wr_full = (wr_gray_next == {~rd_gray_sync2[ADDR_WIDTH:ADDR_WIDTH-1],
                                        rd_gray_sync2[ADDR_WIDTH-2:0]});

    // =========================================================================
    // Read Logic (rd_clk domain)
    // =========================================================================
    wire rd_valid = rd_en && !rd_empty;

    assign rd_bin_next  = rd_bin + rd_valid;
    assign rd_gray_next = rd_bin_next ^ (rd_bin_next >> 1);

    always_ff @(posedge rd_clk or negedge rd_rst_n) begin
        if (!rd_rst_n) begin
            rd_bin  <= '0;
            rd_gray <= '0;
        end else begin
            rd_bin  <= rd_bin_next;
            rd_gray <= rd_gray_next;
        end
    end

    assign rd_data = mem[rd_bin[ADDR_WIDTH-1:0]];

    // Synchronize wr_gray into rd_clk domain (2-FF synchronizer)
    always_ff @(posedge rd_clk or negedge rd_rst_n) begin
        if (!rd_rst_n) begin
            wr_gray_sync1 <= '0;
            wr_gray_sync2 <= '0;
        end else begin
            wr_gray_sync1 <= wr_gray;
            wr_gray_sync2 <= wr_gray_sync1;
        end
    end

    // Empty when read Gray code equals synced write Gray code
    assign rd_empty = (rd_gray_next == wr_gray_sync2);

endmodule
