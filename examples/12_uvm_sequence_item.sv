// UVM Sequence Item Example
//
// Demonstrates how to define a reusable transaction class with:
//   - Randomizable fields and constraints
//   - Factory registration via `uvm_object_utils
//   - Manual do_copy, do_compare, do_print, do_pack, do_unpack
//   - convert2string for debug logging

`ifndef APB_TRANSACTION_SV
`define APB_TRANSACTION_SV

`include "uvm_macros.svh"
import uvm_pkg::*;

typedef enum bit [1:0] {
  APB_IDLE  = 2'b00,
  APB_READ  = 2'b01,
  APB_WRITE = 2'b10,
  APB_ERROR = 2'b11
} apb_op_e;

class apb_transaction extends uvm_sequence_item;

  // ──────────────────────────────────────────────
  //  Fields
  // ──────────────────────────────────────────────
  rand bit [31:0]  addr;
  rand bit [31:0]  data;
  rand apb_op_e    operation;
  rand bit [3:0]   strobe;
  rand int unsigned delay;

  // Response (filled by driver/monitor, not randomized)
  bit        slv_error;
  bit [31:0] read_data;
  time       start_time;
  time       end_time;

  // ──────────────────────────────────────────────
  //  Constraints
  // ──────────────────────────────────────────────
  constraint addr_alignment_c {
    addr[1:0] == 2'b00;
  }

  constraint addr_range_c {
    addr inside {[32'h0000_0000 : 32'h0000_FFFF]};
  }

  constraint valid_operation_c {
    operation inside {APB_READ, APB_WRITE};
  }

  constraint strobe_c {
    operation == APB_WRITE -> strobe != 4'b0000;
    operation == APB_READ  -> strobe == 4'b1111;
  }

  constraint delay_c {
    delay inside {[0:10]};
  }

  // ──────────────────────────────────────────────
  //  Factory Registration
  // ──────────────────────────────────────────────
  `uvm_object_utils(apb_transaction)

  // ──────────────────────────────────────────────
  //  Constructor
  // ──────────────────────────────────────────────
  function new(string name = "apb_transaction");
    super.new(name);
  endfunction

  // ──────────────────────────────────────────────
  //  do_copy — Deep copy all fields
  // ──────────────────────────────────────────────
  virtual function void do_copy(uvm_object rhs);
    apb_transaction rhs_cast;
    super.do_copy(rhs);
    if (!$cast(rhs_cast, rhs))
      `uvm_fatal("COPY", "Cast failed in do_copy")
    this.addr       = rhs_cast.addr;
    this.data       = rhs_cast.data;
    this.operation  = rhs_cast.operation;
    this.strobe     = rhs_cast.strobe;
    this.delay      = rhs_cast.delay;
    this.slv_error  = rhs_cast.slv_error;
    this.read_data  = rhs_cast.read_data;
    this.start_time = rhs_cast.start_time;
    this.end_time   = rhs_cast.end_time;
  endfunction

  // ──────────────────────────────────────────────
  //  do_compare — Field-by-field comparison
  // ──────────────────────────────────────────────
  virtual function bit do_compare(uvm_object rhs, uvm_comparer comparer);
    apb_transaction rhs_cast;
    bit status = super.do_compare(rhs, comparer);
    if (!$cast(rhs_cast, rhs))
      return 0;
    status &= comparer.compare_field_int("addr",      this.addr,      rhs_cast.addr,      32);
    status &= comparer.compare_field_int("data",      this.data,      rhs_cast.data,      32);
    status &= comparer.compare_field_int("operation", this.operation, rhs_cast.operation, 2);
    status &= comparer.compare_field_int("strobe",    this.strobe,    rhs_cast.strobe,    4);
    return status;
  endfunction

  // ──────────────────────────────────────────────
  //  do_print — Formatted field display
  // ──────────────────────────────────────────────
  virtual function void do_print(uvm_printer printer);
    super.do_print(printer);
    printer.print_field_int ("addr",       addr,      32, UVM_HEX);
    printer.print_field_int ("data",       data,      32, UVM_HEX);
    printer.print_string    ("operation",  operation.name());
    printer.print_field_int ("strobe",     strobe,    4,  UVM_BIN);
    printer.print_field_int ("delay",      delay,     32, UVM_DEC);
    printer.print_field_int ("slv_error",  slv_error, 1,  UVM_BIN);
    printer.print_field_int ("read_data",  read_data, 32, UVM_HEX);
  endfunction

  // ──────────────────────────────────────────────
  //  do_pack / do_unpack — Serialization
  // ──────────────────────────────────────────────
  virtual function void do_pack(uvm_packer packer);
    super.do_pack(packer);
    packer.pack_field_int(addr,      32);
    packer.pack_field_int(data,      32);
    packer.pack_field_int(operation, 2);
    packer.pack_field_int(strobe,    4);
    packer.pack_field_int(delay,     32);
  endfunction

  virtual function void do_unpack(uvm_packer packer);
    super.do_unpack(packer);
    addr      = packer.unpack_field_int(32);
    data      = packer.unpack_field_int(32);
    operation = apb_op_e'(packer.unpack_field_int(2));
    strobe    = packer.unpack_field_int(4);
    delay     = packer.unpack_field_int(32);
  endfunction

  // ──────────────────────────────────────────────
  //  convert2string — Human-readable summary
  // ──────────────────────────────────────────────
  virtual function string convert2string();
    return $sformatf("%s addr=0x%08h data=0x%08h strobe=4'b%04b delay=%0d%s",
                     operation.name(), addr, data, strobe, delay,
                     slv_error ? " [ERROR]" : "");
  endfunction

endclass

`endif
