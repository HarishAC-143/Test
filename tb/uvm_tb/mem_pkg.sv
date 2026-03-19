//----------------------------------------------------------------------
// Memory UVM Package
//
// Compilation unit that imports UVM and includes all testbench
// classes in the correct dependency order.
//----------------------------------------------------------------------
package mem_pkg;

  import uvm_pkg::*;
  `include "uvm_macros.svh"

  // Transaction
  `include "mem_seq_item.sv"

  // Sequences
  `include "../sequences/mem_sequences.sv"
  `include "../sequences/mem_virtual_seq.sv"

  // UVM Components
  `include "mem_sequencer.sv"
  `include "mem_driver.sv"
  `include "mem_monitor.sv"
  `include "mem_agent.sv"
  `include "mem_scoreboard.sv"
  `include "mem_coverage.sv"
  `include "mem_env.sv"

  // Tests
  `include "../tests/mem_base_test.sv"
  `include "../tests/mem_write_read_test.sv"
  `include "../tests/mem_random_test.sv"
  `include "../tests/mem_walking_ones_test.sv"
  `include "../tests/mem_virtual_seq_test.sv"

endpackage
