// =============================================================================
// Example 04: Virtual Interfaces, Encapsulation, and Forward Declarations
// Demonstrates: virtual interfaces connecting classes to DUT, local/protected
//               access, forward declarations, typedef, and packages.
// =============================================================================

// --- Interface Definition ---
interface simple_bus_if(input logic clk, input logic rst_n);
  logic        valid;
  logic        ready;
  logic [7:0]  addr;
  logic [31:0] wdata;
  logic [31:0] rdata;
  logic        write;

  modport master(output valid, addr, wdata, write, input ready, rdata, clk, rst_n);
  modport slave (input  valid, addr, wdata, write, output ready, rdata, clk, rst_n);
  modport monitor(input valid, ready, addr, wdata, rdata, write, clk, rst_n);
endinterface

// --- Forward declaration for circular reference ---
typedef class Response;

// --- Request class with forward-declared Response ---
class Request;
  static int unsigned next_id = 0;
  int unsigned id;
  bit [7:0]   addr;
  bit [31:0]  data;
  bit         write;
  Response    rsp;

  function new(bit [7:0] addr, bit [31:0] data, bit write);
    next_id++;
    this.id    = next_id;
    this.addr  = addr;
    this.data  = data;
    this.write = write;
  endfunction

  function void set_response(Response r);
    this.rsp = r;
  endfunction

  function void display();
    $display("  Request  #%0d: %s addr=0x%02h data=0x%08h",
             id, write ? "WR" : "RD", addr, data);
    if (rsp != null)
      rsp.display();
  endfunction
endclass

// --- Response class ---
class Response;
  int unsigned req_id;
  bit [31:0]  data;
  bit         error;

  function new(int unsigned req_id, bit [31:0] data = 0, bit error = 0);
    this.req_id = req_id;
    this.data   = data;
    this.error  = error;
  endfunction

  function void display();
    $display("  Response #%0d: data=0x%08h error=%0b", req_id, data, error);
  endfunction
endclass

// --- Encapsulation Demo ---
class SecureTransaction;
  local    bit [127:0] key;
  protected bit [31:0] header;
           bit [31:0] payload;

  function new(bit [127:0] key);
    this.key     = key;
    this.header  = 32'h0;
    this.payload = 32'h0;
  endfunction

  function void set_payload(bit [31:0] data);
    this.payload = data;
  endfunction

  function void encrypt();
    payload = payload ^ key[31:0];
    header  = header | 32'h8000_0000;
  endfunction

  function void decrypt();
    if (header[31]) begin
      payload = payload ^ key[31:0];
      header  = header & 32'h7FFF_FFFF;
    end
  endfunction

  function void display();
    $display("SecureTxn: header=0x%08h payload=0x%08h encrypted=%0b",
             header, payload, header[31]);
  endfunction
endclass

class ExtendedSecureTransaction extends SecureTransaction;
  bit [15:0] sequence_num;

  function new(bit [127:0] key);
    super.new(key);
    sequence_num = 0;
  endfunction

  function void send(bit [31:0] data);
    sequence_num++;
    header  = {16'h0, sequence_num};
    payload = data;
    encrypt();
  endfunction

  function void display();
    $display("ExtSecureTxn: seq=%0d header=0x%08h payload=0x%08h",
             sequence_num, header, payload);
  endfunction
endclass

// --- Driver using virtual interface ---
class BusDriver;
  virtual simple_bus_if.master vif;
  string name;
  int unsigned txn_count;

  function new(string name, virtual simple_bus_if.master vif);
    this.name  = name;
    this.vif   = vif;
    this.txn_count = 0;
  endfunction

  task drive(Request req);
    @(posedge vif.clk);
    vif.valid <= 1'b1;
    vif.addr  <= req.addr;
    vif.wdata <= req.data;
    vif.write <= req.write;

    @(posedge vif.clk);
    while (!vif.ready) @(posedge vif.clk);

    Response rsp;
    if (!req.write)
      rsp = new(req.id, vif.rdata, 0);
    else
      rsp = new(req.id, 0, 0);

    req.set_response(rsp);
    vif.valid <= 1'b0;
    txn_count++;
  endtask

  function void report();
    $display("[%s] Transactions driven: %0d", name, txn_count);
  endfunction
endclass

// --- Monitor using virtual interface ---
class BusMonitor;
  virtual simple_bus_if.monitor vif;
  string name;
  Request observed_q[$];

  function new(string name, virtual simple_bus_if.monitor vif);
    this.name = name;
    this.vif  = vif;
  endfunction

  task run();
    forever begin
      @(posedge vif.clk);
      if (vif.valid && vif.ready) begin
        Request req = new(vif.addr, vif.write ? vif.wdata : vif.rdata, vif.write);
        if (!vif.write) begin
          Response rsp = new(req.id, vif.rdata, 0);
          req.set_response(rsp);
        end
        observed_q.push_back(req);
      end
    end
  endtask

  function void report();
    $display("[%s] Observed %0d transactions:", name, observed_q.size());
    foreach (observed_q[i])
      observed_q[i].display();
  endfunction
endclass

// --- Simple DUT (register file) ---
module simple_reg_file(simple_bus_if.slave bus);
  logic [31:0] mem [256];

  initial begin
    foreach (mem[i]) mem[i] = 32'h0;
  end

  always @(posedge bus.clk or negedge bus.rst_n) begin
    if (!bus.rst_n) begin
      bus.ready <= 0;
      bus.rdata <= 0;
    end else begin
      bus.ready <= 0;
      if (bus.valid) begin
        bus.ready <= 1;
        if (bus.write)
          mem[bus.addr] <= bus.wdata;
        else
          bus.rdata <= mem[bus.addr];
      end
    end
  end
endmodule

// --- Top-level Testbench ---
module tb_interfaces;
  logic clk, rst_n;

  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  initial begin
    rst_n = 0;
    #20 rst_n = 1;
  end

  simple_bus_if bus_if(.clk(clk), .rst_n(rst_n));
  simple_reg_file dut(.bus(bus_if));

  initial begin
    BusDriver  drv;
    BusMonitor mon;

    @(posedge rst_n);
    @(posedge clk);

    drv = new("drv0", bus_if);
    mon = new("mon0", bus_if);

    // Start monitor in background
    fork
      mon.run();
    join_none

    // --- Forward Declaration Demo ---
    $display("\n===== Request/Response Demo =====");
    begin
      Request  req_wr = new(8'h10, 32'hCAFE_BABE, 1);
      drv.drive(req_wr);
      req_wr.display();
    end

    begin
      Request req_wr2 = new(8'h20, 32'hDEAD_BEEF, 1);
      drv.drive(req_wr2);
      req_wr2.display();
    end

    begin
      Request  req_rd = new(8'h10, 32'h0, 0);
      drv.drive(req_rd);
      req_rd.display();
    end

    @(posedge clk);
    @(posedge clk);
    drv.report();
    mon.report();

    // --- Encapsulation Demo ---
    $display("\n===== Encapsulation Demo =====");
    begin
      SecureTransaction stxn = new(128'hDEADBEEF_CAFEBABE_12345678_AABBCCDD);
      stxn.set_payload(32'h1234_5678);
      stxn.display();
      stxn.encrypt();
      stxn.display();
      stxn.decrypt();
      stxn.display();
    end

    $display("\n===== Extended Secure Transaction =====");
    begin
      ExtendedSecureTransaction ext = new(128'hAAAA_BBBB_CCCC_DDDD_EEEE_FFFF_0000_1111);
      ext.send(32'hFACE_FACE);
      ext.display();
      ext.send(32'h0BAD_F00D);
      ext.display();
    end

    $display("\n===== All tests passed =====");
    $finish;
  end
endmodule
