// APB UVM Package — compiles all testbench components in dependency order
package apb_pkg;

  import uvm_pkg::*;
  `include "uvm_macros.svh"

  `include "apb_seq_item.sv"
  `include "apb_sequencer.sv"
  `include "apb_driver.sv"
  `include "apb_monitor.sv"
  `include "apb_agent.sv"
  `include "apb_scoreboard.sv"
  `include "apb_coverage.sv"
  `include "apb_env.sv"
  `include "apb_sequences.sv"
  `include "apb_tests.sv"

endpackage
