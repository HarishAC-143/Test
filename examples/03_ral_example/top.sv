`include "uvm_macros.svh"

module top;
  import uvm_pkg::*;
  import ral_pkg::*;

  logic pclk;
  logic preset_n;

  initial begin
    pclk = 0;
    forever #5 pclk = ~pclk;
  end

  initial begin
    preset_n = 1'b0;
    repeat(5) @(posedge pclk);
    preset_n = 1'b1;
  end

  apb_if apb_intf(.pclk(pclk), .preset_n(preset_n));

  periph_dut dut (
    .pclk     (pclk),
    .preset_n (preset_n),
    .psel     (apb_intf.psel),
    .penable  (apb_intf.penable),
    .pwrite   (apb_intf.pwrite),
    .paddr    (apb_intf.paddr),
    .pwdata   (apb_intf.pwdata),
    .prdata   (apb_intf.prdata),
    .pready   (apb_intf.pready),
    .irq      ()
  );

  initial begin
    uvm_config_db #(virtual apb_if)::set(null, "uvm_test_top.env.agent*", "vif", apb_intf);
    run_test();
  end
endmodule
