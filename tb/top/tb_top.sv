//----------------------------------------------------------------------
// Testbench Top
//
// Top-level module that:
//   1. Generates clock and reset
//   2. Instantiates the DUT (memory_model)
//   3. Instantiates and connects the interface
//   4. Sets virtual interface in uvm_config_db
//   5. Launches the UVM test selected via +UVM_TESTNAME
//----------------------------------------------------------------------
`timescale 1ns/1ps

module tb_top;

  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import mem_pkg::*;

  //--------------------------------------------------------------------
  // Parameters
  //--------------------------------------------------------------------
  parameter ADDR_WIDTH = 4;
  parameter DATA_WIDTH = 8;
  parameter CLK_PERIOD = 10;

  //--------------------------------------------------------------------
  // Clock and reset generation
  //--------------------------------------------------------------------
  logic clk;
  logic rst_n;

  initial begin
    clk = 0;
    forever #(CLK_PERIOD/2) clk = ~clk;
  end

  initial begin
    rst_n = 0;
    #(CLK_PERIOD * 5);
    rst_n = 1;
    `uvm_info("TB_TOP", "Reset de-asserted", UVM_LOW)
  end

  //--------------------------------------------------------------------
  // Interface instantiation
  //--------------------------------------------------------------------
  mem_if #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH)
  ) mif (
    .clk   (clk),
    .rst_n (rst_n)
  );

  //--------------------------------------------------------------------
  // DUT instantiation
  //--------------------------------------------------------------------
  memory_model #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH),
    .MEM_TYPE  (0)              // 0=flop, 1=latch
  ) dut (
    .clk   (clk),
    .rst_n (rst_n),
    .wr_en (mif.wr_en),
    .rd_en (mif.rd_en),
    .addr  (mif.addr),
    .wdata (mif.wdata),
    .rdata (mif.rdata),
    .valid (mif.valid)
  );

  //--------------------------------------------------------------------
  // UVM configuration and test launch
  //--------------------------------------------------------------------
  initial begin
    uvm_config_db#(virtual mem_if)::set(null, "*", "vif", mif);
    run_test();
  end

  //--------------------------------------------------------------------
  // Waveform dump (optional, simulator-dependent)
  //--------------------------------------------------------------------
  initial begin
    $dumpfile("mem_tb.vcd");
    $dumpvars(0, tb_top);
  end

  //--------------------------------------------------------------------
  // Timeout watchdog
  //--------------------------------------------------------------------
  initial begin
    #1_000_000;
    `uvm_fatal("TB_TOP", "Simulation timeout reached")
  end

endmodule
