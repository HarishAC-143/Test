// FIFO Testbench Package
package fifo_pkg;

  import uvm_pkg::*;
  `include "uvm_macros.svh"

  parameter FIFO_DATA_WIDTH = 8;
  parameter FIFO_DEPTH      = 16;

  typedef enum bit [1:0] {
    FIFO_WRITE = 2'b01,
    FIFO_READ  = 2'b10,
    FIFO_BOTH  = 2'b11,
    FIFO_IDLE  = 2'b00
  } fifo_op_t;

  `include "fifo_transaction.sv"
  `include "fifo_sequence.sv"
  `include "fifo_driver.sv"
  `include "fifo_monitor.sv"
  `include "fifo_scoreboard.sv"
  `include "fifo_agent.sv"
  `include "fifo_env.sv"
  `include "fifo_test.sv"

endpackage
