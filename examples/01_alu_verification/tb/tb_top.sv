// ALU Testbench Top — instantiates the DUT, interface, and starts UVM
module tb_top;

  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import alu_pkg::*;

  // Clock and reset
  logic clk;
  logic rst_n;

  // Clock generation: 10ns period (100 MHz)
  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  // Reset generation
  initial begin
    rst_n = 0;
    #25 rst_n = 1;
  end

  // Instantiate the interface
  alu_if alu_vif(clk, rst_n);

  // Instantiate the DUT and connect through the interface
  alu dut (
    .clk       (clk),
    .rst_n     (rst_n),
    .operand_a (alu_vif.operand_a),
    .operand_b (alu_vif.operand_b),
    .operation (alu_vif.operation),
    .valid_in  (alu_vif.valid_in),
    .result    (alu_vif.result),
    .carry_out (alu_vif.carry_out),
    .zero_flag (alu_vif.zero_flag),
    .valid_out (alu_vif.valid_out)
  );

  // Pass the virtual interface to UVM via config_db
  initial begin
    uvm_config_db #(virtual alu_if)::set(null, "uvm_test_top.env.agent.*", "alu_vif", alu_vif);
    run_test();  // Test name comes from +UVM_TESTNAME command-line argument
  end

endmodule
