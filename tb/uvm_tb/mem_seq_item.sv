//----------------------------------------------------------------------
// Memory Sequence Item (Transaction)
//
// Defines the transaction fields, constraints, and utility methods
// (convert2string, do_compare, do_copy, do_print) following UVM
// best practices.  Field macros are used for automation.
//----------------------------------------------------------------------
class mem_seq_item extends uvm_sequence_item;

  // Transaction fields
  rand bit [3:0] addr;
  rand bit [7:0] wdata;
  rand bit       wr_en;
  rand bit       rd_en;
       bit [7:0] rdata;
       bit       valid;

  // Operation type for readability
  typedef enum bit [1:0] {
    MEM_WRITE = 2'b10,
    MEM_READ  = 2'b01,
    MEM_IDLE  = 2'b00
  } mem_op_t;

  // Field macros for auto print/copy/compare/pack/unpack
  `uvm_object_utils_begin(mem_seq_item)
    `uvm_field_int(addr,  UVM_ALL_ON)
    `uvm_field_int(wdata, UVM_ALL_ON)
    `uvm_field_int(wr_en, UVM_ALL_ON)
    `uvm_field_int(rd_en, UVM_ALL_ON)
    `uvm_field_int(rdata, UVM_ALL_ON)
    `uvm_field_int(valid, UVM_ALL_ON)
  `uvm_object_utils_end

  // Constraints
  constraint valid_op_c {
    !(wr_en && rd_en);  // mutually exclusive
  }

  constraint reasonable_addr_c {
    addr inside {[0:15]};
  }

  function new(string name = "mem_seq_item");
    super.new(name);
  endfunction

  function string convert2string();
    return $sformatf("addr=0x%0h wr_en=%0b rd_en=%0b wdata=0x%0h rdata=0x%0h valid=%0b",
                     addr, wr_en, rd_en, wdata, rdata, valid);
  endfunction

endclass
