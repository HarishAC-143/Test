// Memory transaction — represents one read or write access
typedef enum bit { MEM_WRITE = 1'b1, MEM_READ = 1'b0 } mem_op_e;

class mem_txn extends uvm_sequence_item;

  rand mem_op_e    op;
  rand bit [7:0]   addr;
  rand bit [7:0]   wdata;
       bit [7:0]   rdata;     // captured by monitor on reads
       bit         rvalid;

  `uvm_object_utils_begin(mem_txn)
    `uvm_field_enum(mem_op_e, op, UVM_ALL_ON)
    `uvm_field_int(addr,   UVM_ALL_ON | UVM_HEX)
    `uvm_field_int(wdata,  UVM_ALL_ON | UVM_HEX)
    `uvm_field_int(rdata,  UVM_ALL_ON | UVM_HEX)
    `uvm_field_int(rvalid, UVM_ALL_ON)
  `uvm_object_utils_end

  function new(string name = "mem_txn");
    super.new(name);
  endfunction

  function string convert2string();
    if (op == MEM_WRITE)
      return $sformatf("WRITE addr=0x%02h wdata=0x%02h", addr, wdata);
    else
      return $sformatf("READ  addr=0x%02h rdata=0x%02h", addr, rdata);
  endfunction

endclass
