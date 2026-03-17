// Memory Testbench Package
package mem_pkg;

  import uvm_pkg::*;
  `include "uvm_macros.svh"

  parameter MEM_ADDR_WIDTH = 8;
  parameter MEM_DATA_WIDTH = 32;

  `include "mem_transaction.sv"
  `include "mem_sequence.sv"
  `include "mem_driver.sv"
  `include "mem_monitor.sv"
  `include "mem_scoreboard.sv"
  `include "mem_agent.sv"
  `include "mem_env.sv"
  `include "mem_test.sv"

endpackage
