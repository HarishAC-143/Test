// AXI4-Lite interface
interface axi_lite_if (input logic aclk, input logic aresetn);

  // Write Address Channel
  logic [31:0] awaddr;
  logic        awvalid;
  logic        awready;

  // Write Data Channel
  logic [31:0] wdata;
  logic [3:0]  wstrb;
  logic        wvalid;
  logic        wready;

  // Write Response Channel
  logic [1:0]  bresp;
  logic        bvalid;
  logic        bready;

  // Read Address Channel
  logic [31:0] araddr;
  logic        arvalid;
  logic        arready;

  // Read Data Channel
  logic [31:0] rdata;
  logic [1:0]  rresp;
  logic        rvalid;
  logic        rready;

endinterface
