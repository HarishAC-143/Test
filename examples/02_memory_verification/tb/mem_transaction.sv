// Memory Transaction — represents a single read or write operation
class mem_transaction extends uvm_sequence_item;
  `uvm_object_utils(mem_transaction)

  // Stimulus fields
  rand bit [MEM_ADDR_WIDTH-1:0]  addr;
  rand bit [MEM_DATA_WIDTH-1:0]  wdata;
  rand bit                       write;  // 1 = write, 0 = read

  // Response fields
  bit [MEM_DATA_WIDTH-1:0]  rdata;
  bit                       rvalid;

  constraint addr_range_c {
    addr inside {[0:255]};
  }

  function new(string name = "mem_transaction");
    super.new(name);
  endfunction

  function void do_copy(uvm_object rhs);
    mem_transaction rhs_;
    super.do_copy(rhs);
    $cast(rhs_, rhs);
    this.addr   = rhs_.addr;
    this.wdata  = rhs_.wdata;
    this.write  = rhs_.write;
    this.rdata  = rhs_.rdata;
    this.rvalid = rhs_.rvalid;
  endfunction

  function bit do_compare(uvm_object rhs, uvm_comparer comparer);
    mem_transaction rhs_;
    bit status = super.do_compare(rhs, comparer);
    $cast(rhs_, rhs);
    status &= (this.addr   == rhs_.addr);
    status &= (this.wdata  == rhs_.wdata);
    status &= (this.write  == rhs_.write);
    status &= (this.rdata  == rhs_.rdata);
    return status;
  endfunction

  function string convert2string();
    if (write)
      return $sformatf("WR addr=0x%02h wdata=0x%08h", addr, wdata);
    else
      return $sformatf("RD addr=0x%02h rdata=0x%08h rvalid=%0b", addr, rdata, rvalid);
  endfunction

endclass
