// Asynchronous FIFO with Gray-code pointer synchronization.
//
// Safe for crossing data between two independent clock domains.
// Depth must be a power of two.

module async_fifo #(
    parameter int DATA_WIDTH = 8,
    parameter int DEPTH      = 16
)(
    // Write domain
    input  logic                  wr_clk,
    input  logic                  wr_rst_n,
    input  logic                  wr_en,
    input  logic [DATA_WIDTH-1:0] wr_data,
    output logic                  full,

    // Read domain
    input  logic                  rd_clk,
    input  logic                  rd_rst_n,
    input  logic                  rd_en,
    output logic [DATA_WIDTH-1:0] rd_data,
    output logic                  empty
);

    localparam int PTR_W = $clog2(DEPTH);

    // =========================================================================
    // Dual-port memory (one write port, one read port, different clocks)
    // =========================================================================
    logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    // =========================================================================
    // Write domain
    // =========================================================================
    logic [PTR_W:0] wr_ptr_bin, wr_ptr_gray;
    logic [PTR_W:0] rd_ptr_gray_sync;  // synchronized from read domain

    always_ff @(posedge wr_clk or negedge wr_rst_n) begin
        if (!wr_rst_n) begin
            wr_ptr_bin  <= '0;
            wr_ptr_gray <= '0;
        end else if (wr_en && !full) begin
            mem[wr_ptr_bin[PTR_W-1:0]] <= wr_data;
            wr_ptr_bin  <= wr_ptr_bin + 1'b1;
            wr_ptr_gray <= (wr_ptr_bin + 1'b1) ^ ((wr_ptr_bin + 1'b1) >> 1);
        end
    end

    // Full when Gray-coded pointers match except MSB
    assign full = (wr_ptr_gray == {~rd_ptr_gray_sync[PTR_W:PTR_W-1],
                                    rd_ptr_gray_sync[PTR_W-2:0]});

    // =========================================================================
    // Read domain
    // =========================================================================
    logic [PTR_W:0] rd_ptr_bin, rd_ptr_gray;
    logic [PTR_W:0] wr_ptr_gray_sync;  // synchronized from write domain

    always_ff @(posedge rd_clk or negedge rd_rst_n) begin
        if (!rd_rst_n) begin
            rd_ptr_bin  <= '0;
            rd_ptr_gray <= '0;
        end else if (rd_en && !empty) begin
            rd_ptr_bin  <= rd_ptr_bin + 1'b1;
            rd_ptr_gray <= (rd_ptr_bin + 1'b1) ^ ((rd_ptr_bin + 1'b1) >> 1);
        end
    end

    assign rd_data = mem[rd_ptr_bin[PTR_W-1:0]];

    // Empty when Gray-coded pointers are equal
    assign empty = (rd_ptr_gray == wr_ptr_gray_sync);

    // =========================================================================
    // Gray-code pointer synchronizers
    // =========================================================================

    // Sync write pointer to read domain
    (* async_reg = "true" *)
    logic [PTR_W:0] wr_sync_1, wr_sync_2;

    always_ff @(posedge rd_clk or negedge rd_rst_n) begin
        if (!rd_rst_n) begin
            wr_sync_1 <= '0;
            wr_sync_2 <= '0;
        end else begin
            wr_sync_1 <= wr_ptr_gray;
            wr_sync_2 <= wr_sync_1;
        end
    end
    assign wr_ptr_gray_sync = wr_sync_2;

    // Sync read pointer to write domain
    (* async_reg = "true" *)
    logic [PTR_W:0] rd_sync_1, rd_sync_2;

    always_ff @(posedge wr_clk or negedge wr_rst_n) begin
        if (!wr_rst_n) begin
            rd_sync_1 <= '0;
            rd_sync_2 <= '0;
        end else begin
            rd_sync_1 <= rd_ptr_gray;
            rd_sync_2 <= rd_sync_1;
        end
    end
    assign rd_ptr_gray_sync = rd_sync_2;

endmodule
