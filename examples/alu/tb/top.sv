module top;
  import uvm_pkg::*;
  import alu_pkg::*;
  `include "uvm_macros.svh"

  logic clk;

  // Clock generation: 10ns period (100 MHz)
  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  // Instantiate the interface
  alu_if alu_vif(clk);

  // Instantiate the DUT
  alu dut (
    .clk       (clk),
    .rst_n     (alu_vif.rst_n),
    .operand_a (alu_vif.operand_a),
    .operand_b (alu_vif.operand_b),
    .opcode    (alu_vif.opcode),
    .valid_in  (alu_vif.valid_in),
    .result    (alu_vif.result),
    .valid_out (alu_vif.valid_out),
    .overflow  (alu_vif.overflow)
  );

  initial begin
    // Store the virtual interface in the config database
    uvm_config_db#(virtual alu_if)::set(null, "*", "vif", alu_vif);

    // Start UVM
    run_test();
  end

  // Timeout safety net
  initial begin
    #1_000_000;
    `uvm_fatal("TIMEOUT", "Simulation timed out")
  end
endmodule
