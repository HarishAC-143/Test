// Top-level testbench module — instantiates DUT, interface, and starts UVM
`include "alu_if.sv"
`include "alu.sv"
`include "alu_pkg.sv"

module tb_top;

  import uvm_pkg::*;
  import alu_pkg::*;
  `include "uvm_macros.svh"

  // Clock and reset generation
  bit clk;
  bit rst_n;

  always #5 clk = ~clk;  // 100 MHz (10ns period)

  initial begin
    rst_n = 1'b0;
    #25;
    rst_n = 1'b1;
  end

  // Interface instantiation
  alu_if aif(clk, rst_n);

  // DUT instantiation
  alu dut (
    .clk          (clk),
    .rst_n        (rst_n),
    .operand_a    (aif.operand_a),
    .operand_b    (aif.operand_b),
    .operation    (aif.operation),
    .valid        (aif.valid),
    .result       (aif.result),
    .result_valid (aif.result_valid)
  );

  // Pass virtual interface to UVM and start simulation
  initial begin
    uvm_config_db#(virtual alu_if)::set(null, "*", "alu_vif", aif);
    run_test();  // Test name from +UVM_TESTNAME=<test_class>
  end

  // Waveform dump
  initial begin
    $dumpfile("alu_waves.vcd");
    $dumpvars(0, tb_top);
  end

endmodule
