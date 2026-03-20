class apb_transaction extends uvm_sequence_item;
  `uvm_object_utils(apb_transaction)

  rand bit        write;
  rand bit [7:0]  addr;
  rand bit [31:0] data;

  constraint c_addr_aligned { addr[1:0] == 2'b00; }
  constraint c_addr_range   { addr <= 8'h10; }

  function new(string name = "apb_transaction");
    super.new(name);
  endfunction

  function string convert2string();
    return $sformatf("%s addr=0x%02h data=0x%08h",
                     write ? "WR" : "RD", addr, data);
  endfunction

  function void do_copy(uvm_object rhs);
    apb_transaction rhs_;
    super.do_copy(rhs);
    $cast(rhs_, rhs);
    write = rhs_.write;
    addr  = rhs_.addr;
    data  = rhs_.data;
  endfunction

  function bit do_compare(uvm_object rhs, uvm_comparer comparer);
    apb_transaction rhs_;
    if (!$cast(rhs_, rhs)) return 0;
    return (super.do_compare(rhs, comparer) &&
            write == rhs_.write &&
            addr  == rhs_.addr  &&
            data  == rhs_.data);
  endfunction
endclass
