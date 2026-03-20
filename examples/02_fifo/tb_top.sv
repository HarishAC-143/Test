// Top-level testbench for FIFO verification
`include "uvm_macros.svh"

module tb_top;

  import uvm_pkg::*;
  import fifo_pkg::*;

  parameter DATA_WIDTH = 8;
  parameter DEPTH = 16;

  logic clk;
  logic rst_n;

  // Clock: 100 MHz
  initial begin
    clk = 0;
    forever #5ns clk = ~clk;
  end

  // Reset
  initial begin
    rst_n = 0;
    #50ns;
    rst_n = 1;
  end

  // Interface
  fifo_if #(.DATA_WIDTH(DATA_WIDTH), .DEPTH(DEPTH)) fifo_vif(.clk(clk), .rst_n(rst_n));

  // DUT
  fifo_dut #(.DATA_WIDTH(DATA_WIDTH), .DEPTH(DEPTH)) dut (
    .clk     (clk),
    .rst_n   (rst_n),
    .wr_en   (fifo_vif.wr_en),
    .rd_en   (fifo_vif.rd_en),
    .wr_data (fifo_vif.wr_data),
    .rd_data (fifo_vif.rd_data),
    .full    (fifo_vif.full),
    .empty   (fifo_vif.empty),
    .count   (fifo_vif.count)
  );

  initial begin
    uvm_config_db#(virtual fifo_if)::set(null, "uvm_test_top.env.agent.*", "vif", fifo_vif);
  end

  initial begin
    run_test();
  end

  initial begin
    #5ms;
    `uvm_fatal("TIMEOUT", "Simulation timed out")
  end

  initial begin
    $dumpfile("fifo.vcd");
    $dumpvars(0, tb_top);
  end

endmodule
