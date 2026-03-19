//----------------------------------------------------------------------
// Latch-based Memory Model
//
// Transparent latch storage: when write-enable is high the data input
// passes through to the stored element.  When write-enable goes low
// the last value is held.
//----------------------------------------------------------------------
module mem_latch #(
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

  // Latch-based write: level-sensitive storage
  always_latch begin
    if (wr_en)
      mem[addr] <= wdata;
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

  // Reset memory contents
  always_ff @(negedge rst_n) begin
    if (!rst_n) begin
      for (int i = 0; i < DEPTH; i++)
        mem[i] <= '0;
    end
  end

endmodule
