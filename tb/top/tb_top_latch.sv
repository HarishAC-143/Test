//----------------------------------------------------------------------
// Testbench Top (Latch-based memory variant)
//
// Same structure as tb_top but instantiates the latch-based memory
// model (MEM_TYPE=1) for comparison testing.
//----------------------------------------------------------------------
`timescale 1ns/1ps

module tb_top_latch;

  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import mem_pkg::*;

  parameter ADDR_WIDTH = 4;
  parameter DATA_WIDTH = 8;
  parameter CLK_PERIOD = 10;

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
    `uvm_info("TB_TOP_LATCH", "Reset de-asserted", UVM_LOW)
  end

  mem_if #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH)
  ) mif (
    .clk   (clk),
    .rst_n (rst_n)
  );

  memory_model #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH),
    .MEM_TYPE  (1)              // latch-based
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

  initial begin
    uvm_config_db#(virtual mem_if)::set(null, "*", "vif", mif);
    run_test();
  end

  initial begin
    $dumpfile("mem_tb_latch.vcd");
    $dumpvars(0, tb_top_latch);
  end

  initial begin
    #1_000_000;
    `uvm_fatal("TB_TOP_LATCH", "Simulation timeout reached")
  end

endmodule
