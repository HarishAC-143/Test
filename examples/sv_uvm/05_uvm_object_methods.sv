// =============================================================================
// Example 05: UVM Object Core Methods
// Covers: uvm_object do_copy, do_compare, do_print, convert2string,
//         do_pack, do_unpack, clone, factory registration, and usage
// =============================================================================

`include "uvm_macros.svh"
import uvm_pkg::*;

class spi_transaction extends uvm_sequence_item;
  `uvm_object_utils(spi_transaction)

  rand bit [7:0]  cmd;
  rand bit [23:0] addr;
  rand bit [7:0]  data[];
  rand bit        read_write;   // 0 = read, 1 = write
  rand bit [1:0]  mode;         // SPI mode (CPOL/CPHA)
  bit             status;

  constraint c_data_size { data.size() inside {[1:64]}; }
  constraint c_mode      { mode inside {0, 3}; }
  constraint c_cmd {
    read_write == 0 -> cmd == 8'h03;
    read_write == 1 -> cmd == 8'h02;
  }

  function new(string name = "spi_transaction");
    super.new(name);
  endfunction

  // --- do_copy: field-by-field deep copy ---
  virtual function void do_copy(uvm_object rhs);
    spi_transaction rhs_t;
    super.do_copy(rhs);
    if (!$cast(rhs_t, rhs))
      `uvm_fatal("COPY", "Cast failed in do_copy")
    this.cmd        = rhs_t.cmd;
    this.addr       = rhs_t.addr;
    this.data       = rhs_t.data;
    this.read_write = rhs_t.read_write;
    this.mode       = rhs_t.mode;
    this.status     = rhs_t.status;
  endfunction

  // --- do_compare: field-by-field equality ---
  virtual function bit do_compare(uvm_object rhs, uvm_comparer comparer);
    spi_transaction rhs_t;
    bit status_bit = super.do_compare(rhs, comparer);
    if (!$cast(rhs_t, rhs)) return 0;

    status_bit &= comparer.compare_field_int("cmd",        this.cmd,        rhs_t.cmd,        8);
    status_bit &= comparer.compare_field_int("addr",       this.addr,       rhs_t.addr,       24);
    status_bit &= comparer.compare_field_int("read_write", this.read_write, rhs_t.read_write, 1);
    status_bit &= comparer.compare_field_int("mode",       this.mode,       rhs_t.mode,       2);
    status_bit &= (this.data.size() == rhs_t.data.size());
    if (this.data.size() == rhs_t.data.size())
      foreach (this.data[i])
        status_bit &= comparer.compare_field_int(
          $sformatf("data[%0d]", i), this.data[i], rhs_t.data[i], 8);

    return status_bit;
  endfunction

  // --- convert2string: one-line summary ---
  virtual function string convert2string();
    string s = $sformatf("SPI %s cmd=0x%02h addr=0x%06h mode=%0d data_len=%0d",
                         read_write ? "WR" : "RD", cmd, addr, mode, data.size());
    if (data.size() <= 8) begin
      s = {s, " data=["};
      foreach (data[i])
        s = {s, $sformatf("%s0x%02h", (i > 0) ? "," : "", data[i])};
      s = {s, "]"};
    end
    return s;
  endfunction

  // --- do_print: structured printer output ---
  virtual function void do_print(uvm_printer printer);
    super.do_print(printer);
    printer.print_field_int("cmd",        cmd,        8,  UVM_HEX);
    printer.print_field_int("addr",       addr,       24, UVM_HEX);
    printer.print_field_int("read_write", read_write, 1,  UVM_BIN);
    printer.print_field_int("mode",       mode,       2,  UVM_DEC);
    printer.print_field_int("data_size",  data.size(), 32, UVM_DEC);
    foreach (data[i])
      printer.print_field_int($sformatf("data[%0d]", i), data[i], 8, UVM_HEX);
    printer.print_field_int("status",     status,     1,  UVM_BIN);
  endfunction

  // --- do_pack / do_unpack: serialization ---
  virtual function void do_pack(uvm_packer packer);
    super.do_pack(packer);
    packer.pack_field_int(cmd,        8);
    packer.pack_field_int(addr,       24);
    packer.pack_field_int(read_write, 1);
    packer.pack_field_int(mode,       2);
    packer.pack_field_int(data.size(), 32);
    foreach (data[i])
      packer.pack_field_int(data[i], 8);
    packer.pack_field_int(status,     1);
  endfunction

  virtual function void do_unpack(uvm_packer packer);
    int sz;
    super.do_unpack(packer);
    cmd        = packer.unpack_field_int(8);
    addr       = packer.unpack_field_int(24);
    read_write = packer.unpack_field_int(1);
    mode       = packer.unpack_field_int(2);
    sz         = packer.unpack_field_int(32);
    data = new[sz];
    foreach (data[i])
      data[i] = packer.unpack_field_int(8);
    status = packer.unpack_field_int(1);
  endfunction
endclass


class demo_test extends uvm_test;
  `uvm_component_utils(demo_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual task run_phase(uvm_phase phase);
    spi_transaction t1, t2, t3, t_unpacked;
    uvm_object      cloned_obj;
    bit             match;
    bit             bitstream[];
    int             num_bits;

    phase.raise_objection(this);

    // --- Create via factory ---
    t1 = spi_transaction::type_id::create("t1");
    void'(t1.randomize() with {
      read_write == 1;
      addr       == 24'h001000;
      data.size() == 4;
    });

    `uvm_info("TEST", {"=== convert2string ===\n  ", t1.convert2string()}, UVM_LOW)

    `uvm_info("TEST", "=== print (table format) ===", UVM_LOW)
    t1.print();

    // --- Copy ---
    t2 = spi_transaction::type_id::create("t2");
    t2.copy(t1);
    `uvm_info("TEST", {"=== After copy ===\n  t2: ", t2.convert2string()}, UVM_LOW)

    // Modify t2 to verify independence
    t2.addr = 24'h002000;
    t2.data[0] = 8'hFF;
    `uvm_info("TEST", {"  t1 unchanged: ", t1.convert2string()}, UVM_LOW)
    `uvm_info("TEST", {"  t2 modified:  ", t2.convert2string()}, UVM_LOW)

    // --- Compare ---
    t3 = spi_transaction::type_id::create("t3");
    t3.copy(t1);
    match = t1.compare(t3);
    `uvm_info("TEST", $sformatf("=== Compare t1 vs t3 (identical): %s ===",
              match ? "MATCH" : "MISMATCH"), UVM_LOW)

    t3.data[0] = 8'hAA;
    match = t1.compare(t3);
    `uvm_info("TEST", $sformatf("=== Compare t1 vs t3 (modified): %s ===",
              match ? "MATCH" : "MISMATCH"), UVM_LOW)

    // --- Clone ---
    cloned_obj = t1.clone();
    `uvm_info("TEST", $sformatf("=== Clone type: %s ===", cloned_obj.get_type_name()), UVM_LOW)

    // --- Pack / Unpack ---
    num_bits = t1.pack(bitstream);
    `uvm_info("TEST", $sformatf("=== Packed %0d bits ===", num_bits), UVM_LOW)

    t_unpacked = spi_transaction::type_id::create("t_unpacked");
    num_bits = t_unpacked.unpack(bitstream);
    `uvm_info("TEST", $sformatf("=== Unpacked %0d bits ===", num_bits), UVM_LOW)

    match = t1.compare(t_unpacked);
    `uvm_info("TEST", $sformatf("=== Pack/unpack roundtrip: %s ===",
              match ? "MATCH" : "MISMATCH"), UVM_LOW)
    `uvm_info("TEST", {"  Original:  ", t1.convert2string()}, UVM_LOW)
    `uvm_info("TEST", {"  Unpacked:  ", t_unpacked.convert2string()}, UVM_LOW)

    phase.drop_objection(this);
  endtask
endclass


module tb_uvm_object;
  initial begin
    run_test("demo_test");
  end
endmodule
