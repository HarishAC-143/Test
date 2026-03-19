//----------------------------------------------------------------------
// Memory Interface
//
// Virtual interface used by UVM driver and monitor to communicate
// with the DUT.
//----------------------------------------------------------------------
interface mem_if #(
  parameter ADDR_WIDTH = 4,
  parameter DATA_WIDTH = 8
)(
  input logic clk,
  input logic rst_n
);

  logic                  wr_en;
  logic                  rd_en;
  logic [ADDR_WIDTH-1:0] addr;
  logic [DATA_WIDTH-1:0] wdata;
  logic [DATA_WIDTH-1:0] rdata;
  logic                  valid;

  // Driver clocking block
  clocking driver_cb @(posedge clk);
    default input #1 output #1;
    output wr_en;
    output rd_en;
    output addr;
    output wdata;
    input  rdata;
    input  valid;
  endclocking

  // Monitor clocking block
  clocking monitor_cb @(posedge clk);
    default input #1 output #1;
    input wr_en;
    input rd_en;
    input addr;
    input wdata;
    input rdata;
    input valid;
  endclocking

  modport driver_mp  (clocking driver_cb,  input clk, input rst_n);
  modport monitor_mp (clocking monitor_cb, input clk, input rst_n);

endinterface
