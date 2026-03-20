// AXI4-Lite interface definition
interface axi_lite_if #(
  parameter ADDR_WIDTH = 6,
  parameter DATA_WIDTH = 32
)(
  input logic aclk
);
  logic                    aresetn;

  // Write address channel
  logic [ADDR_WIDTH-1:0]   awaddr;
  logic                    awvalid;
  logic                    awready;

  // Write data channel
  logic [DATA_WIDTH-1:0]   wdata;
  logic [DATA_WIDTH/8-1:0] wstrb;
  logic                    wvalid;
  logic                    wready;

  // Write response channel
  logic [1:0]              bresp;
  logic                    bvalid;
  logic                    bready;

  // Read address channel
  logic [ADDR_WIDTH-1:0]   araddr;
  logic                    arvalid;
  logic                    arready;

  // Read data channel
  logic [DATA_WIDTH-1:0]   rdata;
  logic [1:0]              rresp;
  logic                    rvalid;
  logic                    rready;

  clocking master_cb @(posedge aclk);
    default input #1 output #1;
    output awaddr, awvalid, wdata, wstrb, wvalid, bready;
    output araddr, arvalid, rready;
    output aresetn;
    input  awready, wready, bresp, bvalid;
    input  arready, rdata, rresp, rvalid;
  endclocking

  clocking monitor_cb @(posedge aclk);
    default input #1;
    input awaddr, awvalid, awready;
    input wdata, wstrb, wvalid, wready;
    input bresp, bvalid, bready;
    input araddr, arvalid, arready;
    input rdata, rresp, rvalid, rready;
    input aresetn;
  endclocking

  modport master  (clocking master_cb);
  modport monitor (clocking monitor_cb);
endinterface
