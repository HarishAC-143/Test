// FIFO Sequence Item
class fifo_seq_item extends uvm_sequence_item;

  rand bit       wr_en;
  rand bit       rd_en;
  rand bit [7:0] wr_data;

  bit [7:0] rd_data;
  bit       full;
  bit       empty;

  `uvm_object_utils_begin(fifo_seq_item)
    `uvm_field_int(wr_en,   UVM_ALL_ON)
    `uvm_field_int(rd_en,   UVM_ALL_ON)
    `uvm_field_int(wr_data, UVM_ALL_ON)
    `uvm_field_int(rd_data, UVM_ALL_ON)
    `uvm_field_int(full,    UVM_ALL_ON)
    `uvm_field_int(empty,   UVM_ALL_ON)
  `uvm_object_utils_end

  // Don't write and read simultaneously (keep things simple for this example)
  constraint no_simultaneous_c {
    !(wr_en && rd_en);
    wr_en || rd_en;
  }

  function new(string name = "fifo_seq_item");
    super.new(name);
  endfunction

  function string convert2string();
    if (wr_en)
      return $sformatf("WRITE data=0x%02h full=%0b empty=%0b", wr_data, full, empty);
    else if (rd_en)
      return $sformatf("READ  data=0x%02h full=%0b empty=%0b", rd_data, full, empty);
    else
      return "IDLE";
  endfunction

endclass
