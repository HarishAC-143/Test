class mem_transaction extends uvm_sequence_item;
  `uvm_object_utils(mem_transaction)

  typedef enum bit { MEM_READ = 0, MEM_WRITE = 1 } mem_op_e;

  rand bit [7:0]  addr;
  rand bit [31:0] wdata;
  rand bit        we;
  rand bit        re;
  rand bit [3:0]  be;
  bit [31:0]      rdata;
  bit             rvalid;

  constraint c_valid_op {
    we != re;  // mutually exclusive
  }

  constraint c_be {
    we -> be != 0;  // at least one byte enabled on writes
    !we -> be == 4'hF;
  }

  constraint c_addr_alignment {
    soft addr[1:0] == 0;  // prefer word-aligned, but can be overridden
  }

  function new(string name = "mem_transaction");
    super.new(name);
  endfunction

  function string convert2string();
    string op_str = we ? "WRITE" : "READ";
    if (we)
      return $sformatf("%s addr=0x%02h wdata=0x%08h be=0x%01h",
                       op_str, addr, wdata, be);
    else
      return $sformatf("%s addr=0x%02h rdata=0x%08h rvalid=%0b",
                       op_str, addr, rdata, rvalid);
  endfunction

  function bit do_compare(uvm_object rhs, uvm_comparer comparer);
    mem_transaction rhs_;
    if (!$cast(rhs_, rhs)) return 0;
    return (addr  == rhs_.addr)  &&
           (wdata == rhs_.wdata) &&
           (we    == rhs_.we)    &&
           (re    == rhs_.re)    &&
           (be    == rhs_.be)    &&
           (rdata == rhs_.rdata);
  endfunction

  function void do_copy(uvm_object rhs);
    mem_transaction rhs_;
    super.do_copy(rhs);
    $cast(rhs_, rhs);
    addr   = rhs_.addr;
    wdata  = rhs_.wdata;
    we     = rhs_.we;
    re     = rhs_.re;
    be     = rhs_.be;
    rdata  = rhs_.rdata;
    rvalid = rhs_.rvalid;
  endfunction
endclass
