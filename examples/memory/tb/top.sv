module top;
  import uvm_pkg::*;
  import mem_pkg::*;
  `include "uvm_macros.svh"

  logic clk;

  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  mem_if mem_vif(clk);

  sync_mem #(
    .ADDR_WIDTH(8),
    .DATA_WIDTH(32)
  ) dut (
    .clk    (clk),
    .rst_n  (mem_vif.rst_n),
    .addr   (mem_vif.addr),
    .wdata  (mem_vif.wdata),
    .rdata  (mem_vif.rdata),
    .we     (mem_vif.we),
    .re     (mem_vif.re),
    .be     (mem_vif.be),
    .rvalid (mem_vif.rvalid)
  );

  initial begin
    uvm_config_db#(virtual mem_if)::set(null, "*", "vif", mem_vif);
    run_test();
  end

  initial begin
    #5_000_000;
    `uvm_fatal("TIMEOUT", "Simulation timed out")
  end
endmodule
