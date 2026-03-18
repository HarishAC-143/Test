// Asynchronous FIFO with Gray-Code Pointers
// Safe data transfer between two independent clock domains.
// Uses dual-port RAM, Gray-coded pointers, and 2-flop synchronizers.

module async_fifo #(
    parameter int DATA_WIDTH = 8,
    parameter int DEPTH      = 16,
    localparam int ADDR_WIDTH = $clog2(DEPTH)
) (
    // Write domain
    input  logic                  wr_clk,
    input  logic                  wr_rst_n,
    input  logic                  wr_en,
    input  logic [DATA_WIDTH-1:0] wr_data,
    output logic                  wr_full,

    // Read domain
    input  logic                  rd_clk,
    input  logic                  rd_rst_n,
    input  logic                  rd_en,
    output logic [DATA_WIDTH-1:0] rd_data,
    output logic                  rd_empty
);

    // Dual-port RAM
    logic [DATA_WIDTH-1:0] mem [DEPTH];

    // Binary and Gray-code pointers — (ADDR_WIDTH+1) bits for wrap detection
    logic [ADDR_WIDTH:0] wr_bin, wr_bin_next;
    logic [ADDR_WIDTH:0] wr_gray, wr_gray_next;
    logic [ADDR_WIDTH:0] rd_bin, rd_bin_next;
    logic [ADDR_WIDTH:0] rd_gray, rd_gray_next;

    // Synchronized Gray pointers
    logic [ADDR_WIDTH:0] wr_gray_sync1, wr_gray_sync2;  // wr_gray in read domain
    logic [ADDR_WIDTH:0] rd_gray_sync1, rd_gray_sync2;  // rd_gray in write domain

    // --- Gray-code conversion functions ---
    function automatic logic [ADDR_WIDTH:0] bin2gray(input logic [ADDR_WIDTH:0] bin);
        return bin ^ (bin >> 1);
    endfunction

    // --- Write domain logic ---
    logic wr_valid;
    assign wr_valid    = wr_en && !wr_full;
    assign wr_bin_next  = wr_valid ? wr_bin + 1 : wr_bin;
    assign wr_gray_next = bin2gray(wr_bin_next);

    always_ff @(posedge wr_clk or negedge wr_rst_n) begin
        if (!wr_rst_n) begin
            wr_bin  <= '0;
            wr_gray <= '0;
        end else begin
            wr_bin  <= wr_bin_next;
            wr_gray <= wr_gray_next;
        end
    end

    // Write to memory
    always_ff @(posedge wr_clk) begin
        if (wr_valid)
            mem[wr_bin[ADDR_WIDTH-1:0]] <= wr_data;
    end

    // Full detection: MSBs differ (wrapped), remaining bits same
    assign wr_full = (wr_gray_next == {~rd_gray_sync2[ADDR_WIDTH:ADDR_WIDTH-1],
                                        rd_gray_sync2[ADDR_WIDTH-2:0]});

    // --- Read domain logic ---
    logic rd_valid;
    assign rd_valid    = rd_en && !rd_empty;
    assign rd_bin_next  = rd_valid ? rd_bin + 1 : rd_bin;
    assign rd_gray_next = bin2gray(rd_bin_next);

    always_ff @(posedge rd_clk or negedge rd_rst_n) begin
        if (!rd_rst_n) begin
            rd_bin  <= '0;
            rd_gray <= '0;
        end else begin
            rd_bin  <= rd_bin_next;
            rd_gray <= rd_gray_next;
        end
    end

    // Read from memory (combinational read for minimum latency)
    assign rd_data = mem[rd_bin[ADDR_WIDTH-1:0]];

    // Empty detection: pointers match
    assign rd_empty = (rd_gray_next == wr_gray_sync2);

    // --- 2-Flop synchronizers ---

    // Synchronize wr_gray into read clock domain
    always_ff @(posedge rd_clk or negedge rd_rst_n) begin
        if (!rd_rst_n) begin
            wr_gray_sync1 <= '0;
            wr_gray_sync2 <= '0;
        end else begin
            wr_gray_sync1 <= wr_gray;
            wr_gray_sync2 <= wr_gray_sync1;
        end
    end

    // Synchronize rd_gray into write clock domain
    always_ff @(posedge wr_clk or negedge wr_rst_n) begin
        if (!wr_rst_n) begin
            rd_gray_sync1 <= '0;
            rd_gray_sync2 <= '0;
        end else begin
            rd_gray_sync1 <= rd_gray;
            rd_gray_sync2 <= rd_gray_sync1;
        end
    end

endmodule
