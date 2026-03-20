// Top-level testbench for SRAM verification
`include "mem_if.sv"
`include "sram.sv"
`include "mem_pkg.sv"

module tb_top;

  import uvm_pkg::*;
  import mem_pkg::*;
  `include "uvm_macros.svh"

  bit clk;
  bit rst_n;

  always #5 clk = ~clk;

  initial begin
    rst_n = 1'b0;
    #25;
    rst_n = 1'b1;
  end

  // Interface
  mem_if mif(clk, rst_n);

  // DUT
  sram dut (
    .clk    (clk),
    .rst_n  (rst_n),
    .cs     (mif.cs),
    .we     (mif.we),
    .addr   (mif.addr),
    .wdata  (mif.wdata),
    .rdata  (mif.rdata),
    .rvalid (mif.rvalid)
  );

  initial begin
    uvm_config_db#(virtual mem_if)::set(null, "*", "mem_vif", mif);
    run_test();
  end

  initial begin
    $dumpfile("mem_waves.vcd");
    $dumpvars(0, tb_top);
  end

endmodule
