// =============================================================================
// Asynchronous FIFO for Clock Domain Crossing (CDC)
// Demonstrates: Gray code pointers, multi-clock design, synchronizers
// =============================================================================

module gray_code_sync #(
    parameter int WIDTH = 4
) (
    input  logic             clk,
    input  logic             rst_n,
    input  logic [WIDTH-1:0] data_in,
    output logic [WIDTH-1:0] data_out
);
    logic [WIDTH-1:0] sync_stage1, sync_stage2;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sync_stage1 <= '0;
            sync_stage2 <= '0;
        end else begin
            sync_stage1 <= data_in;
            sync_stage2 <= sync_stage1;
        end
    end

    assign data_out = sync_stage2;
endmodule


module async_fifo #(
    parameter int DATA_WIDTH = 8,
    parameter int DEPTH      = 16
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

    localparam int ADDR_WIDTH = $clog2(DEPTH);
    localparam int PTR_WIDTH  = ADDR_WIDTH + 1;

    // Dual-port memory
    logic [DATA_WIDTH-1:0] mem [DEPTH];

    // Binary and Gray code pointers
    logic [PTR_WIDTH-1:0] wr_ptr_bin, wr_ptr_gray;
    logic [PTR_WIDTH-1:0] rd_ptr_bin, rd_ptr_gray;

    // Synchronized pointers (crossed between domains)
    logic [PTR_WIDTH-1:0] wr_ptr_gray_sync; // wr_ptr in rd_clk domain
    logic [PTR_WIDTH-1:0] rd_ptr_gray_sync; // rd_ptr in wr_clk domain

    // Binary-to-Gray conversion
    function automatic logic [PTR_WIDTH-1:0] bin2gray(input logic [PTR_WIDTH-1:0] bin);
        return bin ^ (bin >> 1);
    endfunction

    // =========================================================================
    // Write Clock Domain
    // =========================================================================

    always_ff @(posedge wr_clk or negedge wr_rst_n) begin
        if (!wr_rst_n) begin
            wr_ptr_bin  <= '0;
            wr_ptr_gray <= '0;
        end else if (wr_en && !wr_full) begin
            wr_ptr_bin  <= wr_ptr_bin + 1'b1;
            wr_ptr_gray <= bin2gray(wr_ptr_bin + 1'b1);
        end
    end

    always_ff @(posedge wr_clk) begin
        if (wr_en && !wr_full)
            mem[wr_ptr_bin[ADDR_WIDTH-1:0]] <= wr_data;
    end

    // Full: MSBs differ, remaining bits match (in Gray code)
    assign wr_full = (wr_ptr_gray[PTR_WIDTH-1]     != rd_ptr_gray_sync[PTR_WIDTH-1]) &&
                     (wr_ptr_gray[PTR_WIDTH-2]     != rd_ptr_gray_sync[PTR_WIDTH-2]) &&
                     (wr_ptr_gray[PTR_WIDTH-3:0]   == rd_ptr_gray_sync[PTR_WIDTH-3:0]);

    // =========================================================================
    // Read Clock Domain
    // =========================================================================

    always_ff @(posedge rd_clk or negedge rd_rst_n) begin
        if (!rd_rst_n) begin
            rd_ptr_bin  <= '0;
            rd_ptr_gray <= '0;
        end else if (rd_en && !rd_empty) begin
            rd_ptr_bin  <= rd_ptr_bin + 1'b1;
            rd_ptr_gray <= bin2gray(rd_ptr_bin + 1'b1);
        end
    end

    assign rd_data  = mem[rd_ptr_bin[ADDR_WIDTH-1:0]];
    assign rd_empty = (rd_ptr_gray == wr_ptr_gray_sync);

    // =========================================================================
    // Cross-domain synchronizers
    // =========================================================================

    gray_code_sync #(.WIDTH(PTR_WIDTH)) wr_to_rd_sync (
        .clk      (rd_clk),
        .rst_n    (rd_rst_n),
        .data_in  (wr_ptr_gray),
        .data_out (wr_ptr_gray_sync)
    );

    gray_code_sync #(.WIDTH(PTR_WIDTH)) rd_to_wr_sync (
        .clk      (wr_clk),
        .rst_n    (wr_rst_n),
        .data_in  (rd_ptr_gray),
        .data_out (rd_ptr_gray_sync)
    );

endmodule
