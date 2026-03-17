// ALU Testbench Package — bundles all UVM components
package alu_pkg;

  import uvm_pkg::*;
  `include "uvm_macros.svh"

  typedef enum bit [2:0] {
    ALU_ADD = 3'b000,
    ALU_SUB = 3'b001,
    ALU_AND = 3'b010,
    ALU_OR  = 3'b011,
    ALU_XOR = 3'b100
  } alu_op_t;

  `include "alu_transaction.sv"
  `include "alu_sequence.sv"
  `include "alu_driver.sv"
  `include "alu_monitor.sv"
  `include "alu_scoreboard.sv"
  `include "alu_coverage.sv"
  `include "alu_agent.sv"
  `include "alu_env.sv"
  `include "alu_test.sv"

endpackage
