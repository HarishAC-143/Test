// ============================================================================
// Asynchronous FIFO with Gray-Code Pointers
// ============================================================================
// Transfers data safely between two independent clock domains using:
//   - Dual-port RAM (write port on wr_clk, read port on rd_clk)
//   - Gray-coded write and read pointers
//   - Two-flop synchronizers to cross pointer values between domains
//
// The DEPTH must be a power of 2 for correct Gray-code operation.
//
// Reference: Cliff Cummings, "Simulation and Synthesis Techniques for
// Asynchronous FIFO Design" (SNUG 2002)
// ============================================================================

module async_fifo #(
    parameter int WIDTH = 8,
    parameter int DEPTH = 16  // must be power of 2
)(
    // Write clock domain
    input  logic             wr_clk,
    input  logic             wr_rst_n,
    input  logic             wr_en,
    input  logic [WIDTH-1:0] wr_data,
    output logic             full,

    // Read clock domain
    input  logic             rd_clk,
    input  logic             rd_rst_n,
    input  logic             rd_en,
    output logic [WIDTH-1:0] rd_data,
    output logic             empty
);

    localparam int ADDR_W = $clog2(DEPTH);

    // -------------------------------------------------------------------------
    // Dual-port memory
    // -------------------------------------------------------------------------
    logic [WIDTH-1:0] mem [DEPTH];

    // -------------------------------------------------------------------------
    // Write domain signals
    // -------------------------------------------------------------------------
    logic [ADDR_W:0] wr_ptr_bin, wr_ptr_bin_next;
    logic [ADDR_W:0] wr_ptr_gray, wr_ptr_gray_next;

    // Read pointer synchronized into write domain
    (* async_reg = "true" *)
    logic [ADDR_W:0] rd_ptr_gray_sync [2];

    assign wr_ptr_bin_next  = wr_ptr_bin + 1'b1;
    assign wr_ptr_gray_next = wr_ptr_bin_next ^ (wr_ptr_bin_next >> 1);

    always_ff @(posedge wr_clk or negedge wr_rst_n) begin
        if (!wr_rst_n) begin
            wr_ptr_bin  <= '0;
            wr_ptr_gray <= '0;
        end else if (wr_en && !full) begin
            mem[wr_ptr_bin[ADDR_W-1:0]] <= wr_data;
            wr_ptr_bin  <= wr_ptr_bin_next;
            wr_ptr_gray <= wr_ptr_gray_next;
        end
    end

    // Synchronize rd_ptr_gray → wr_clk
    always_ff @(posedge wr_clk or negedge wr_rst_n) begin
        if (!wr_rst_n) begin
            rd_ptr_gray_sync[0] <= '0;
            rd_ptr_gray_sync[1] <= '0;
        end else begin
            rd_ptr_gray_sync[0] <= rd_ptr_gray;
            rd_ptr_gray_sync[1] <= rd_ptr_gray_sync[0];
        end
    end

    // Full: gray codes match but MSBs are inverted
    assign full = (wr_ptr_gray == {~rd_ptr_gray_sync[1][ADDR_W:ADDR_W-1],
                                     rd_ptr_gray_sync[1][ADDR_W-2:0]});

    // -------------------------------------------------------------------------
    // Read domain signals
    // -------------------------------------------------------------------------
    logic [ADDR_W:0] rd_ptr_bin, rd_ptr_bin_next;
    logic [ADDR_W:0] rd_ptr_gray, rd_ptr_gray_next;

    // Write pointer synchronized into read domain
    (* async_reg = "true" *)
    logic [ADDR_W:0] wr_ptr_gray_sync [2];

    assign rd_ptr_bin_next  = rd_ptr_bin + 1'b1;
    assign rd_ptr_gray_next = rd_ptr_bin_next ^ (rd_ptr_bin_next >> 1);

    always_ff @(posedge rd_clk or negedge rd_rst_n) begin
        if (!rd_rst_n) begin
            rd_ptr_bin  <= '0;
            rd_ptr_gray <= '0;
        end else if (rd_en && !empty) begin
            rd_ptr_bin  <= rd_ptr_bin_next;
            rd_ptr_gray <= rd_ptr_gray_next;
        end
    end

    // Synchronize wr_ptr_gray → rd_clk
    always_ff @(posedge rd_clk or negedge rd_rst_n) begin
        if (!rd_rst_n) begin
            wr_ptr_gray_sync[0] <= '0;
            wr_ptr_gray_sync[1] <= '0;
        end else begin
            wr_ptr_gray_sync[0] <= wr_ptr_gray;
            wr_ptr_gray_sync[1] <= wr_ptr_gray_sync[0];
        end
    end

    // Empty: gray codes match exactly
    assign empty   = (rd_ptr_gray == wr_ptr_gray_sync[1]);
    assign rd_data = mem[rd_ptr_bin[ADDR_W-1:0]];

endmodule
