interface fifo_if #(
  parameter DATA_WIDTH = 8,
  parameter DEPTH      = 16
)(
  input logic clk,
  input logic rst_n
);

  logic                  wr_en;
  logic [DATA_WIDTH-1:0] wr_data;
  logic                  rd_en;
  logic [DATA_WIDTH-1:0] rd_data;
  logic                  full;
  logic                  empty;
  logic                  almost_full;
  logic                  almost_empty;
  logic [$clog2(DEPTH):0] count;
  logic                  overflow;
  logic                  underflow;

  clocking wr_drv_cb @(posedge clk);
    default input #1 output #1;
    output wr_en, wr_data;
    input  full, almost_full, count, overflow;
  endclocking

  clocking rd_drv_cb @(posedge clk);
    default input #1 output #1;
    output rd_en;
    input  rd_data, empty, almost_empty, count, underflow;
  endclocking

  clocking mon_cb @(posedge clk);
    default input #1;
    input wr_en, wr_data, rd_en, rd_data;
    input full, empty, almost_full, almost_empty;
    input count, overflow, underflow;
  endclocking

  modport WR_DRV (clocking wr_drv_cb, input clk, rst_n);
  modport RD_DRV (clocking rd_drv_cb, input clk, rst_n);
  modport MON    (clocking mon_cb, input clk, rst_n);

endinterface
