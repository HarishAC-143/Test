// Synchronous Memory — Design Under Test
// Single-port RAM with synchronous read and write
module sync_mem #(
  parameter ADDR_WIDTH = 8,
  parameter DATA_WIDTH = 32,
  parameter MEM_DEPTH  = 2**ADDR_WIDTH
)(
  input  logic                    clk,
  input  logic                    rst_n,
  input  logic [ADDR_WIDTH-1:0]   addr,
  input  logic [DATA_WIDTH-1:0]   wdata,
  input  logic                    wr_en,
  input  logic                    rd_en,
  output logic [DATA_WIDTH-1:0]   rdata,
  output logic                    rvalid
);

  logic [DATA_WIDTH-1:0] mem [0:MEM_DEPTH-1];

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      rdata  <= '0;
      rvalid <= 1'b0;
    end else begin
      rvalid <= 1'b0;

      if (wr_en) begin
        mem[addr] <= wdata;
      end

      if (rd_en) begin
        rdata  <= mem[addr];
        rvalid <= 1'b1;
      end
    end
  end

endmodule
