class axi_lite_transaction extends uvm_sequence_item;
  `uvm_object_utils(axi_lite_transaction)

  typedef enum bit { AXI_READ = 0, AXI_WRITE = 1 } axi_rw_e;
  typedef enum bit [1:0] {
    AXI_OKAY   = 2'b00,
    AXI_EXOKAY = 2'b01,
    AXI_SLVERR = 2'b10,
    AXI_DECERR = 2'b11
  } axi_resp_e;

  // Request fields
  rand bit [5:0]  addr;
  rand bit [31:0] wdata;
  rand bit [3:0]  wstrb;
  rand bit        rw;  // 0=read, 1=write

  // Response fields
  bit [31:0] rdata;
  bit [1:0]  resp;

  constraint c_addr_aligned {
    addr[1:0] == 2'b00;
  }

  constraint c_wstrb {
    rw == AXI_WRITE -> wstrb != 0;
    rw == AXI_READ  -> wstrb == 4'hF;
  }

  constraint c_addr_range {
    addr < 6'h40;
  }

  function new(string name = "axi_lite_transaction");
    super.new(name);
  endfunction

  function string convert2string();
    if (rw == AXI_WRITE)
      return $sformatf("WRITE addr=0x%02h wdata=0x%08h wstrb=0x%01h resp=%02b",
                       addr, wdata, wstrb, resp);
    else
      return $sformatf("READ  addr=0x%02h rdata=0x%08h resp=%02b",
                       addr, rdata, resp);
  endfunction

  function bit do_compare(uvm_object rhs, uvm_comparer comparer);
    axi_lite_transaction rhs_;
    if (!$cast(rhs_, rhs)) return 0;
    return (addr  == rhs_.addr)  &&
           (wdata == rhs_.wdata) &&
           (wstrb == rhs_.wstrb) &&
           (rw    == rhs_.rw)    &&
           (rdata == rhs_.rdata) &&
           (resp  == rhs_.resp);
  endfunction

  function void do_copy(uvm_object rhs);
    axi_lite_transaction rhs_;
    super.do_copy(rhs);
    $cast(rhs_, rhs);
    addr  = rhs_.addr;
    wdata = rhs_.wdata;
    wstrb = rhs_.wstrb;
    rw    = rhs_.rw;
    rdata = rhs_.rdata;
    resp  = rhs_.resp;
  endfunction
endclass
