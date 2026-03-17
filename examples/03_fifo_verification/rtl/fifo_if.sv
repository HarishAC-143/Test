// FIFO Interface
interface fifo_if #(
  parameter DATA_WIDTH = 8,
  parameter FIFO_DEPTH = 16,
  parameter ADDR_WIDTH = $clog2(FIFO_DEPTH)
)(
  input logic clk,
  input logic rst_n
);

  logic [DATA_WIDTH-1:0]  wr_data;
  logic                   wr_en;
  logic                   full;
  logic [DATA_WIDTH-1:0]  rd_data;
  logic                   rd_en;
  logic                   empty;
  logic [ADDR_WIDTH:0]    count;

  clocking driver_cb @(posedge clk);
    default input #1step output #0;
    output wr_data;
    output wr_en;
    input  full;
    output rd_en;
    input  rd_data;
    input  empty;
    input  count;
  endclocking

  clocking monitor_cb @(posedge clk);
    default input #1step output #0;
    input wr_data;
    input wr_en;
    input full;
    input rd_data;
    input rd_en;
    input empty;
    input count;
  endclocking

  modport driver_mp  (clocking driver_cb, input clk, input rst_n);
  modport monitor_mp (clocking monitor_cb, input clk, input rst_n);

endinterface
