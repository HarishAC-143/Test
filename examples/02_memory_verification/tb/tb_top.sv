// Memory Testbench Top
module tb_top;

  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import mem_pkg::*;

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

  mem_if #(
    .ADDR_WIDTH(MEM_ADDR_WIDTH),
    .DATA_WIDTH(MEM_DATA_WIDTH)
  ) mem_vif(clk, rst_n);

  sync_mem #(
    .ADDR_WIDTH(MEM_ADDR_WIDTH),
    .DATA_WIDTH(MEM_DATA_WIDTH)
  ) dut (
    .clk   (clk),
    .rst_n (rst_n),
    .addr  (mem_vif.addr),
    .wdata (mem_vif.wdata),
    .wr_en (mem_vif.wr_en),
    .rd_en (mem_vif.rd_en),
    .rdata (mem_vif.rdata),
    .rvalid(mem_vif.rvalid)
  );

  initial begin
    uvm_config_db #(virtual mem_if)::set(null, "uvm_test_top.env.agent.*", "mem_vif", mem_vif);
    run_test();
  end

endmodule
