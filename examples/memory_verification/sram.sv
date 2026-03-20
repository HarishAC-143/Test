// DUT: Synchronous single-port SRAM (256 x 8-bit)
module sram (
  input  logic        clk,
  input  logic        rst_n,
  input  logic        cs,      // chip select
  input  logic        we,      // write enable
  input  logic [7:0]  addr,
  input  logic [7:0]  wdata,
  output logic [7:0]  rdata,
  output logic        rvalid
);

  logic [7:0] mem [0:255];

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      rdata  <= 8'd0;
      rvalid <= 1'b0;
    end else if (cs) begin
      if (we) begin
        mem[addr] <= wdata;
        rdata     <= 8'd0;
        rvalid    <= 1'b0;
      end else begin
        rdata  <= mem[addr];
        rvalid <= 1'b1;
      end
    end else begin
      rdata  <= 8'd0;
      rvalid <= 1'b0;
    end
  end

endmodule
