//----------------------------------------------------------------------
// Flop-based Memory Model
//
// Edge-triggered (flip-flop) storage: data is captured on the rising
// edge of the clock when write-enable is asserted.
//----------------------------------------------------------------------
module mem_flop #(
  parameter ADDR_WIDTH = 4,
  parameter DATA_WIDTH = 8,
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

  logic [DATA_WIDTH-1:0] mem [DEPTH];

  // Flop-based write: edge-triggered storage
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (int i = 0; i < DEPTH; i++)
        mem[i] <= '0;
    end else if (wr_en) begin
      mem[addr] <= wdata;
    end
  end

  // Synchronous read
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      rdata <= '0;
      valid <= 1'b0;
    end else if (rd_en) begin
      rdata <= mem[addr];
      valid <= 1'b1;
    end else begin
      valid <= 1'b0;
    end
  end

endmodule
