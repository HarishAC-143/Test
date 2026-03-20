// Synchronous single-port SRAM with byte-enable
module sync_mem #(
  parameter ADDR_WIDTH = 8,
  parameter DATA_WIDTH = 32,
  parameter DEPTH      = 2**ADDR_WIDTH
)(
  input  logic                    clk,
  input  logic                    rst_n,
  input  logic [ADDR_WIDTH-1:0]   addr,
  input  logic [DATA_WIDTH-1:0]   wdata,
  output logic [DATA_WIDTH-1:0]   rdata,
  input  logic                    we,
  input  logic                    re,
  input  logic [DATA_WIDTH/8-1:0] be,
  output logic                    rvalid
);

  logic [DATA_WIDTH-1:0] mem [DEPTH];

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      rdata  <= '0;
      rvalid <= 1'b0;
    end else begin
      rvalid <= re;

      if (we) begin
        for (int i = 0; i < DATA_WIDTH/8; i++) begin
          if (be[i])
            mem[addr][i*8 +: 8] <= wdata[i*8 +: 8];
        end
      end

      if (re)
        rdata <= mem[addr];
    end
  end

endmodule
