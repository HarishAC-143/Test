package axi_lite_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  `include "axi_lite_transaction.sv"
  `include "axi_lite_sequences.sv"
  `include "axi_lite_driver.sv"
  `include "axi_lite_monitor.sv"
  `include "axi_lite_sequencer.sv"
  `include "axi_lite_agent.sv"
  `include "axi_lite_scoreboard.sv"
  `include "axi_lite_coverage.sv"
  `include "axi_lite_env.sv"
  `include "axi_lite_test.sv"
endpackage
