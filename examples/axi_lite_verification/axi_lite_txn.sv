// AXI-Lite transaction
typedef enum bit { AXI_WRITE = 1'b1, AXI_READ = 1'b0 } axi_dir_e;
typedef enum bit [1:0] {
  AXI_OKAY   = 2'b00,
  AXI_EXOKAY = 2'b01,
  AXI_SLVERR = 2'b10,
  AXI_DECERR = 2'b11
} axi_resp_e;

class axi_lite_txn extends uvm_sequence_item;

  rand axi_dir_e   dir;
  rand bit [31:0]  addr;
  rand bit [31:0]  data;
  rand bit [3:0]   strb;
       axi_resp_e  resp;

  `uvm_object_utils_begin(axi_lite_txn)
    `uvm_field_enum(axi_dir_e, dir, UVM_ALL_ON)
    `uvm_field_int(addr, UVM_ALL_ON | UVM_HEX)
    `uvm_field_int(data, UVM_ALL_ON | UVM_HEX)
    `uvm_field_int(strb, UVM_ALL_ON | UVM_BIN)
    `uvm_field_enum(axi_resp_e, resp, UVM_ALL_ON)
  `uvm_object_utils_end

  // Word-aligned addresses, valid register range
  constraint addr_aligned {
    addr[1:0] == 2'b00;
  }

  constraint valid_addr_range {
    addr inside {32'h00, 32'h04, 32'h08, 32'h0C};
  }

  constraint strb_default {
    strb == 4'b1111;  // full-word access by default
  }

  function new(string name = "axi_lite_txn");
    super.new(name);
  endfunction

  function string convert2string();
    if (dir == AXI_WRITE)
      return $sformatf("AXI WRITE: addr=0x%08h data=0x%08h strb=%04b resp=%s",
                       addr, data, strb, resp.name());
    else
      return $sformatf("AXI READ:  addr=0x%08h data=0x%08h resp=%s",
                       addr, data, resp.name());
  endfunction

endclass
