// Top-level testbench module for APB Slave verification
//
// Usage (with a simulator that supports UVM):
//   # Compile and run with VCS:
//   vcs -sverilog -ntb_opts uvm tb_top.sv apb_slave_dut.sv +UVM_TESTNAME=apb_write_read_test
//
//   # Compile and run with Questa:
//   vlog -sv tb_top.sv apb_slave_dut.sv
//   vsim -c tb_top +UVM_TESTNAME=apb_write_read_test -do "run -all"
//
//   # Compile and run with Xcelium:
//   xrun -sv -uvm tb_top.sv apb_slave_dut.sv +UVM_TESTNAME=apb_write_read_test

`include "uvm_macros.svh"

module tb_top;

  import uvm_pkg::*;
  import apb_pkg::*;

  // Clock and reset
  logic pclk;
  logic preset_n;

  // Clock generation: 100 MHz
  initial begin
    pclk = 0;
    forever #5ns pclk = ~pclk;
  end

  // Reset generation
  initial begin
    preset_n = 0;
    #50ns;
    preset_n = 1;
  end

  // APB interface instance
  apb_if apb_vif(.pclk(pclk), .preset_n(preset_n));

  // DUT instantiation
  apb_slave_dut dut (
    .pclk     (pclk),
    .preset_n (preset_n),
    .paddr    (apb_vif.paddr),
    .psel     (apb_vif.psel),
    .penable  (apb_vif.penable),
    .pwrite   (apb_vif.pwrite),
    .pwdata   (apb_vif.pwdata),
    .prdata   (apb_vif.prdata),
    .pready   (apb_vif.pready),
    .pslverr  (apb_vif.pslverr)
  );

  // Pass virtual interface to testbench via config_db
  initial begin
    uvm_config_db#(virtual apb_if)::set(null, "uvm_test_top.env.agent.*", "vif", apb_vif);
  end

  // Start UVM test
  initial begin
    run_test();
  end

  // Timeout watchdog
  initial begin
    #1ms;
    `uvm_fatal("TIMEOUT", "Simulation timed out after 1ms")
  end

  // Dump waveforms (optional, simulator-dependent)
  initial begin
    $dumpfile("apb_slave.vcd");
    $dumpvars(0, tb_top);
  end

endmodule
