interface apb_if #(
  parameter ADDR_WIDTH = 8,
  parameter DATA_WIDTH = 32
)(
  input logic pclk,
  input logic preset_n
);

  logic                    psel;
  logic                    penable;
  logic                    pwrite;
  logic [ADDR_WIDTH-1:0]   paddr;
  logic [DATA_WIDTH-1:0]   pwdata;
  logic [DATA_WIDTH/8-1:0] pstrb;
  logic [DATA_WIDTH-1:0]   prdata;
  logic                    pready;
  logic                    pslverr;

  // Driver clocking block
  clocking drv_cb @(posedge pclk);
    default input #1 output #1;
    output psel, penable, pwrite, paddr, pwdata, pstrb;
    input  prdata, pready, pslverr;
  endclocking

  // Monitor clocking block
  clocking mon_cb @(posedge pclk);
    default input #1;
    input psel, penable, pwrite, paddr, pwdata, pstrb;
    input prdata, pready, pslverr;
  endclocking

  modport DRV (clocking drv_cb, input pclk, preset_n);
  modport MON (clocking mon_cb, input pclk, preset_n);

  // Protocol assertions
  property p_penable_after_psel;
    @(posedge pclk) disable iff (!preset_n)
    ($rose(psel) && !penable) |=> penable;
  endproperty

  property p_stable_during_access;
    @(posedge pclk) disable iff (!preset_n)
    (psel && penable && !pready) |=> (psel && $stable(paddr) && $stable(pwrite));
  endproperty

  property p_psel_stable_during_transfer;
    @(posedge pclk) disable iff (!preset_n)
    (psel && !penable) |=> psel;
  endproperty

  assert property (p_penable_after_psel)
    else $error("APB Protocol Violation: PENABLE must rise one cycle after PSEL");

  assert property (p_stable_during_access)
    else $error("APB Protocol Violation: PADDR/PWRITE must be stable during transfer");

  assert property (p_psel_stable_during_transfer)
    else $error("APB Protocol Violation: PSEL dropped during transfer");

endinterface
