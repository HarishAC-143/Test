interface apb_if (input logic pclk, input logic preset_n);

  logic        psel;
  logic        penable;
  logic        pwrite;
  logic [7:0]  paddr;
  logic [31:0] pwdata;
  logic [31:0] prdata;
  logic        pready;

  clocking drv_cb @(posedge pclk);
    default input #1 output #1;
    output psel, penable, pwrite, paddr, pwdata;
    input  prdata, pready;
  endclocking

  clocking mon_cb @(posedge pclk);
    default input #1;
    input psel, penable, pwrite, paddr, pwdata, prdata, pready;
  endclocking

  modport DRV (clocking drv_cb, input pclk, preset_n);
  modport MON (clocking mon_cb, input pclk, preset_n);

endinterface
