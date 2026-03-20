// APB Sequence Item — represents a single APB transaction
class apb_seq_item extends uvm_sequence_item;

  rand bit [31:0] addr;
  rand bit [31:0] data;
  rand bit        write;
  bit [31:0]      rdata;
  bit             slverr;

  `uvm_object_utils_begin(apb_seq_item)
    `uvm_field_int(addr,   UVM_ALL_ON)
    `uvm_field_int(data,   UVM_ALL_ON)
    `uvm_field_int(write,  UVM_ALL_ON)
    `uvm_field_int(rdata,  UVM_ALL_ON)
    `uvm_field_int(slverr, UVM_ALL_ON)
  `uvm_object_utils_end

  // Constrain address to the valid 256-word range (word-aligned)
  constraint valid_addr_c {
    addr[31:10] == 0;
    addr[1:0]   == 0;
  }

  function new(string name = "apb_seq_item");
    super.new(name);
  endfunction

  function string convert2string();
    return $sformatf("%s addr=0x%08h wdata=0x%08h rdata=0x%08h err=%0b",
                     write ? "WRITE" : "READ ", addr, data, rdata, slverr);
  endfunction

endclass
