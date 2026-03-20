module top;
  import uvm_pkg::*;
  import axi_lite_pkg::*;
  `include "uvm_macros.svh"

  logic clk;

  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  axi_lite_if axi_vif(clk);

  axi_lite_slave #(
    .ADDR_WIDTH(6),
    .DATA_WIDTH(32),
    .NUM_REGS(16)
  ) dut (
    .aclk      (clk),
    .aresetn   (axi_vif.aresetn),
    .s_awaddr  (axi_vif.awaddr),
    .s_awvalid (axi_vif.awvalid),
    .s_awready (axi_vif.awready),
    .s_wdata   (axi_vif.wdata),
    .s_wstrb   (axi_vif.wstrb),
    .s_wvalid  (axi_vif.wvalid),
    .s_wready  (axi_vif.wready),
    .s_bresp   (axi_vif.bresp),
    .s_bvalid  (axi_vif.bvalid),
    .s_bready  (axi_vif.bready),
    .s_araddr  (axi_vif.araddr),
    .s_arvalid (axi_vif.arvalid),
    .s_arready (axi_vif.arready),
    .s_rdata   (axi_vif.rdata),
    .s_rresp   (axi_vif.rresp),
    .s_rvalid  (axi_vif.rvalid),
    .s_rready  (axi_vif.rready)
  );

  initial begin
    uvm_config_db#(virtual axi_lite_if)::set(null, "*", "vif", axi_vif);
    run_test();
  end

  initial begin
    #10_000_000;
    `uvm_fatal("TIMEOUT", "Simulation timed out")
  end
endmodule
