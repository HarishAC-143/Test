//----------------------------------------------------------------------
// Top-level Memory Model
//
// Parameterized wrapper that selects between latch-based and
// flop-based storage via the MEM_TYPE parameter.
//   MEM_TYPE = 0 -> flop-based (default)
//   MEM_TYPE = 1 -> latch-based
//----------------------------------------------------------------------
module memory_model #(
  parameter ADDR_WIDTH = 4,
  parameter DATA_WIDTH = 8,
  parameter MEM_TYPE   = 0,          // 0 = flop, 1 = latch
  parameter DEPTH      = 1 << ADDR_WIDTH
)(
  input  logic                  clk,
  input  logic                  rst_n,
  input  logic                  wr_en,
  input  logic                  rd_en,
  input  logic [ADDR_WIDTH-1:0] addr,
  input  logic [DATA_WIDTH-1:0] wdata,
  output logic [DATA_WIDTH-1:0] rdata,
  output logic                  valid
);

  generate
    if (MEM_TYPE == 1) begin : g_latch
      mem_latch #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH     (DEPTH)
      ) u_mem (
        .clk   (clk),
        .rst_n (rst_n),
        .wr_en (wr_en),
        .rd_en (rd_en),
        .addr  (addr),
        .wdata (wdata),
        .rdata (rdata),
        .valid (valid)
      );
    end else begin : g_flop
      mem_flop #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH     (DEPTH)
      ) u_mem (
        .clk   (clk),
        .rst_n (rst_n),
        .wr_en (wr_en),
        .rd_en (rd_en),
        .addr  (addr),
        .wdata (wdata),
        .rdata (rdata),
        .valid (valid)
      );
    end
  endgenerate

endmodule
