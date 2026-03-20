`include "uvm_macros.svh"

module top;
  import uvm_pkg::*;
  import fifo_pkg::*;

  logic clk;
  logic rst_n;

  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  initial begin
    rst_n = 1'b0;
    repeat(5) @(posedge clk);
    rst_n = 1'b1;
  end

  fifo_if #(.DATA_WIDTH(8), .DEPTH(16)) fifo_intf(.clk(clk), .rst_n(rst_n));

  fifo_dut #(
    .DATA_WIDTH(8),
    .DEPTH(16)
  ) dut (
    .clk          (clk),
    .rst_n        (rst_n),
    .wr_en        (fifo_intf.wr_en),
    .wr_data      (fifo_intf.wr_data),
    .rd_en        (fifo_intf.rd_en),
    .rd_data      (fifo_intf.rd_data),
    .full         (fifo_intf.full),
    .empty        (fifo_intf.empty),
    .almost_full  (fifo_intf.almost_full),
    .almost_empty (fifo_intf.almost_empty),
    .count        (fifo_intf.count),
    .overflow     (fifo_intf.overflow),
    .underflow    (fifo_intf.underflow)
  );

  initial begin
    uvm_config_db #(virtual fifo_if)::set(null, "uvm_test_top.env.agent*", "vif", fifo_intf);
    run_test();
  end
endmodule
