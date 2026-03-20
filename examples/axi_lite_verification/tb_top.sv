// Top-level testbench for AXI-Lite slave verification
`include "axi_lite_if.sv"
`include "axi_lite_slave.sv"
`include "axi_lite_pkg.sv"

module tb_top;

  import uvm_pkg::*;
  import axi_lite_pkg::*;
  `include "uvm_macros.svh"

  bit aclk;
  bit aresetn;

  always #5 aclk = ~aclk;

  initial begin
    aresetn = 1'b0;
    #50;
    aresetn = 1'b1;
  end

  // Interface
  axi_lite_if axif(aclk, aresetn);

  // DUT
  axi_lite_slave dut (
    .aclk           (aclk),
    .aresetn        (aresetn),

    .s_axi_awaddr   (axif.awaddr),
    .s_axi_awvalid  (axif.awvalid),
    .s_axi_awready  (axif.awready),

    .s_axi_wdata    (axif.wdata),
    .s_axi_wstrb    (axif.wstrb),
    .s_axi_wvalid   (axif.wvalid),
    .s_axi_wready   (axif.wready),

    .s_axi_bresp    (axif.bresp),
    .s_axi_bvalid   (axif.bvalid),
    .s_axi_bready   (axif.bready),

    .s_axi_araddr   (axif.araddr),
    .s_axi_arvalid  (axif.arvalid),
    .s_axi_arready  (axif.arready),

    .s_axi_rdata    (axif.rdata),
    .s_axi_rresp    (axif.rresp),
    .s_axi_rvalid   (axif.rvalid),
    .s_axi_rready   (axif.rready)
  );

  initial begin
    uvm_config_db#(virtual axi_lite_if)::set(null, "*", "axi_vif", axif);
    run_test();
  end

  initial begin
    $dumpfile("axi_lite_waves.vcd");
    $dumpvars(0, tb_top);
  end

endmodule
