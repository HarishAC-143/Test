interface mem_if #(
  parameter ADDR_WIDTH = 8,
  parameter DATA_WIDTH = 32
)(
  input logic clk
);
  logic                    rst_n;
  logic [ADDR_WIDTH-1:0]   addr;
  logic [DATA_WIDTH-1:0]   wdata;
  logic [DATA_WIDTH-1:0]   rdata;
  logic                    we;
  logic                    re;
  logic [DATA_WIDTH/8-1:0] be;
  logic                    rvalid;

  clocking driver_cb @(posedge clk);
    default input #1 output #1;
    output addr, wdata, we, re, be, rst_n;
    input  rdata, rvalid;
  endclocking

  clocking monitor_cb @(posedge clk);
    default input #1;
    input addr, wdata, we, re, be, rst_n, rdata, rvalid;
  endclocking

  modport driver  (clocking driver_cb);
  modport monitor (clocking monitor_cb);
endinterface
