`include "uvm_macros.svh"

module top;
  import uvm_pkg::*;
  import apb_pkg::*;

  logic pclk;
  logic preset_n;

  // Clock: 10ns period
  initial begin
    pclk = 0;
    forever #5 pclk = ~pclk;
  end

  // Reset
  initial begin
    preset_n = 1'b0;
    repeat(5) @(posedge pclk);
    preset_n = 1'b1;
  end

  // Interface
  apb_if #(.ADDR_WIDTH(8), .DATA_WIDTH(32)) apb_intf(.pclk(pclk), .preset_n(preset_n));

  // DUT
  apb_slave_dut #(
    .ADDR_WIDTH(8),
    .DATA_WIDTH(32),
    .MEM_DEPTH(64)
  ) dut (
    .pclk     (pclk),
    .preset_n (preset_n),
    .psel     (apb_intf.psel),
    .penable  (apb_intf.penable),
    .pwrite   (apb_intf.pwrite),
    .paddr    (apb_intf.paddr),
    .pwdata   (apb_intf.pwdata),
    .pstrb    (apb_intf.pstrb),
    .prdata   (apb_intf.prdata),
    .pready   (apb_intf.pready),
    .pslverr  (apb_intf.pslverr)
  );

  // UVM setup
  initial begin
    uvm_config_db #(virtual apb_if)::set(null, "uvm_test_top.env.agent*", "vif", apb_intf);
    run_test();
  end
endmodule
