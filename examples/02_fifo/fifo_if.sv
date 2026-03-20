// Synchronous FIFO Interface
interface fifo_if #(parameter DATA_WIDTH = 8, parameter DEPTH = 16)
  (input logic clk, input logic rst_n);

  logic                  wr_en;
  logic                  rd_en;
  logic [DATA_WIDTH-1:0] wr_data;
  logic [DATA_WIDTH-1:0] rd_data;
  logic                  full;
  logic                  empty;
  logic [$clog2(DEPTH):0] count;

  clocking driver_cb @(posedge clk);
    default input #1 output #1;
    output wr_en, rd_en, wr_data;
    input  rd_data, full, empty, count;
  endclocking

  clocking monitor_cb @(posedge clk);
    default input #1 output #1;
    input wr_en, rd_en, wr_data;
    input rd_data, full, empty, count;
  endclocking

  modport driver  (clocking driver_cb, input clk, rst_n);
  modport monitor (clocking monitor_cb, input clk, rst_n);

endinterface
