// FIFO Testbench Top
module tb_top;

  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import fifo_pkg::*;

  logic clk;
  logic rst_n;

  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  initial begin
    rst_n = 0;
    #25 rst_n = 1;
  end

  fifo_if #(
    .DATA_WIDTH(FIFO_DATA_WIDTH),
    .FIFO_DEPTH(FIFO_DEPTH)
  ) fifo_vif(clk, rst_n);

  sync_fifo #(
    .DATA_WIDTH(FIFO_DATA_WIDTH),
    .FIFO_DEPTH(FIFO_DEPTH)
  ) dut (
    .clk     (clk),
    .rst_n   (rst_n),
    .wr_data (fifo_vif.wr_data),
    .wr_en   (fifo_vif.wr_en),
    .full    (fifo_vif.full),
    .rd_data (fifo_vif.rd_data),
    .rd_en   (fifo_vif.rd_en),
    .empty   (fifo_vif.empty),
    .count   (fifo_vif.count)
  );

  initial begin
    uvm_config_db #(virtual fifo_if)::set(null, "uvm_test_top.env.agent.*", "fifo_vif", fifo_vif);
    run_test();
  end

endmodule
