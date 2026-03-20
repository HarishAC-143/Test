// SystemVerilog interface for the SRAM
interface mem_if (input logic clk, input logic rst_n);

  logic        cs;
  logic        we;
  logic [7:0]  addr;
  logic [7:0]  wdata;
  logic [7:0]  rdata;
  logic        rvalid;

  // Clocking block for driver
  clocking driver_cb @(posedge clk);
    default input #1 output #1;
    output cs;
    output we;
    output addr;
    output wdata;
    input  rdata;
    input  rvalid;
  endclocking

  // Clocking block for monitor
  clocking monitor_cb @(posedge clk);
    default input #1 output #1;
    input cs;
    input we;
    input addr;
    input wdata;
    input rdata;
    input rvalid;
  endclocking

  modport drv_mp (clocking driver_cb, input clk, input rst_n);
  modport mon_mp (clocking monitor_cb, input clk, input rst_n);

endinterface
