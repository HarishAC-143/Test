// Memory Interface
interface mem_if #(
  parameter ADDR_WIDTH = 8,
  parameter DATA_WIDTH = 32
)(
  input logic clk,
  input logic rst_n
);

  logic [ADDR_WIDTH-1:0]  addr;
  logic [DATA_WIDTH-1:0]  wdata;
  logic                   wr_en;
  logic                   rd_en;
  logic [DATA_WIDTH-1:0]  rdata;
  logic                   rvalid;

  clocking driver_cb @(posedge clk);
    default input #1step output #0;
    output addr;
    output wdata;
    output wr_en;
    output rd_en;
    input  rdata;
    input  rvalid;
  endclocking

  clocking monitor_cb @(posedge clk);
    default input #1step output #0;
    input addr;
    input wdata;
    input wr_en;
    input rd_en;
    input rdata;
    input rvalid;
  endclocking

  modport driver_mp  (clocking driver_cb, input clk, input rst_n);
  modport monitor_mp (clocking monitor_cb, input clk, input rst_n);

endinterface
