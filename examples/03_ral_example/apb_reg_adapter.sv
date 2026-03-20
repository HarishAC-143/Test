class apb_reg_adapter extends uvm_reg_adapter;
  `uvm_object_utils(apb_reg_adapter)

  function new(string name = "apb_reg_adapter");
    super.new(name);
    supports_byte_enable = 0;
    provides_responses   = 0;
  endfunction

  virtual function uvm_sequence_item reg2bus(const ref uvm_reg_bus_op rw);
    apb_transaction tx = apb_transaction::type_id::create("tx");
    tx.write = (rw.kind == UVM_WRITE);
    tx.addr  = rw.addr[7:0];
    tx.data  = rw.data;
    return tx;
  endfunction

  virtual function void bus2reg(uvm_sequence_item bus_item, ref uvm_reg_bus_op rw);
    apb_transaction tx;
    if (!$cast(tx, bus_item))
      `uvm_fatal("CAST", "Failed to cast bus_item to apb_transaction")
    rw.kind   = tx.write ? UVM_WRITE : UVM_READ;
    rw.addr   = {24'h0, tx.addr};
    rw.data   = tx.data;
    rw.status = UVM_IS_OK;
  endfunction
endclass
