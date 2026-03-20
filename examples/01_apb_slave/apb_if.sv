// APB (AMBA Peripheral Bus) Interface Definition
interface apb_if(input logic pclk, input logic preset_n);

  logic [31:0] paddr;
  logic        psel;
  logic        penable;
  logic        pwrite;
  logic [31:0] pwdata;
  logic [31:0] prdata;
  logic        pready;
  logic        pslverr;

  // Driver clocking block
  clocking driver_cb @(posedge pclk);
    default input #1 output #1;
    output paddr, psel, penable, pwrite, pwdata;
    input  prdata, pready, pslverr;
  endclocking

  // Monitor clocking block
  clocking monitor_cb @(posedge pclk);
    default input #1 output #1;
    input paddr, psel, penable, pwrite, pwdata;
    input prdata, pready, pslverr;
  endclocking

  modport driver  (clocking driver_cb, input pclk, input preset_n);
  modport monitor (clocking monitor_cb, input pclk, input preset_n);

endinterface
