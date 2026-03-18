// ----------------------------------------------------------------------------
// Asynchronous FIFO (Dual-Clock Domain)
// Demonstrates: Gray-code pointers, multi-flop synchronizers,
//               CDC-safe full/empty generation, dual-port RAM
// ----------------------------------------------------------------------------

module async_fifo #(
    parameter int DATA_WIDTH = 32,
    parameter int DEPTH      = 16
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

    localparam int ADDR_WIDTH = $clog2(DEPTH);
    localparam int PTR_WIDTH  = ADDR_WIDTH + 1;

    // Dual-port memory
    logic [DATA_WIDTH-1:0] mem [DEPTH];

    // Binary and Gray-code pointers
    logic [PTR_WIDTH-1:0] wr_ptr_bin,  wr_ptr_gray;
    logic [PTR_WIDTH-1:0] rd_ptr_bin,  rd_ptr_gray;

    // Synchronized Gray-code pointers (crossed between domains)
    logic [PTR_WIDTH-1:0] wr_ptr_gray_sync1, wr_ptr_gray_sync2; // wr_ptr in rd domain
    logic [PTR_WIDTH-1:0] rd_ptr_gray_sync1, rd_ptr_gray_sync2; // rd_ptr in wr domain

    // ---------- Binary-to-Gray Conversion ----------
    function automatic logic [PTR_WIDTH-1:0] bin2gray(input logic [PTR_WIDTH-1:0] bin);
        return bin ^ (bin >> 1);
    endfunction

    // ---------- Write Logic (wr_clk domain) ----------
    wire wr_valid = wr_en && !full;

    always_ff @(posedge wr_clk or negedge wr_rst_n) begin
        if (!wr_rst_n) begin
            wr_ptr_bin  <= '0;
            wr_ptr_gray <= '0;
        end else if (wr_valid) begin
            wr_ptr_bin  <= wr_ptr_bin + 1'b1;
            wr_ptr_gray <= bin2gray(wr_ptr_bin + 1'b1);
        end
    end

    always_ff @(posedge wr_clk) begin
        if (wr_valid)
            mem[wr_ptr_bin[ADDR_WIDTH-1:0]] <= wr_data;
    end

    // ---------- Read Logic (rd_clk domain) ----------
    wire rd_valid = rd_en && !empty;

    always_ff @(posedge rd_clk or negedge rd_rst_n) begin
        if (!rd_rst_n) begin
            rd_ptr_bin  <= '0;
            rd_ptr_gray <= '0;
        end else if (rd_valid) begin
            rd_ptr_bin  <= rd_ptr_bin + 1'b1;
            rd_ptr_gray <= bin2gray(rd_ptr_bin + 1'b1);
        end
    end

    assign rd_data = mem[rd_ptr_bin[ADDR_WIDTH-1:0]];

    // ---------- Pointer Synchronizers (2-FF) ----------

    // Synchronize wr_ptr_gray into rd_clk domain
    always_ff @(posedge rd_clk or negedge rd_rst_n) begin
        if (!rd_rst_n) begin
            wr_ptr_gray_sync1 <= '0;
            wr_ptr_gray_sync2 <= '0;
        end else begin
            wr_ptr_gray_sync1 <= wr_ptr_gray;
            wr_ptr_gray_sync2 <= wr_ptr_gray_sync1;
        end
    end

    // Synchronize rd_ptr_gray into wr_clk domain
    always_ff @(posedge wr_clk or negedge wr_rst_n) begin
        if (!wr_rst_n) begin
            rd_ptr_gray_sync1 <= '0;
            rd_ptr_gray_sync2 <= '0;
        end else begin
            rd_ptr_gray_sync1 <= rd_ptr_gray;
            rd_ptr_gray_sync2 <= rd_ptr_gray_sync1;
        end
    end

    // ---------- Full and Empty Flags ----------
    // Full: MSBs differ, remaining bits match (in Gray code)
    assign full = (wr_ptr_gray == {~rd_ptr_gray_sync2[PTR_WIDTH-1:PTR_WIDTH-2],
                                     rd_ptr_gray_sync2[PTR_WIDTH-3:0]});

    // Empty: Gray pointers are identical
    assign empty = (rd_ptr_gray == wr_ptr_gray_sync2);

endmodule
