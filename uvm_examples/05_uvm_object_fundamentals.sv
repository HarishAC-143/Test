// =============================================================================
// Example 05: UVM Object Fundamentals
// Demonstrates: uvm_object, factory registration, do_copy, do_compare,
//               do_print, do_pack/do_unpack, convert2string, clone.
// =============================================================================

`include "uvm_macros.svh"
import uvm_pkg::*;

// --- Transaction with full do-methods ---
class SPI_Transaction extends uvm_sequence_item;
  `uvm_object_utils(SPI_Transaction)

  rand bit [7:0]  cmd;
  rand bit [23:0] address;
  rand bit [7:0]  data[];
  rand bit        read_write;   // 0=read, 1=write
       bit [7:0]  response[];
       bit        status;

  constraint c_data_size {
    data.size() inside {[1:32]};
  }

  constraint c_read_no_data {
    read_write == 0 -> data.size() == 0;
  }

  constraint c_address_range {
    address inside {[24'h00_0000:24'h0F_FFFF]};
  }

  function new(string name = "SPI_Transaction");
    super.new(name);
  endfunction

  // --- do_copy: deep copy all fields ---
  virtual function void do_copy(uvm_object rhs);
    SPI_Transaction rhs_;
    super.do_copy(rhs);
    if (!$cast(rhs_, rhs))
      `uvm_fatal("CAST", "do_copy cast failed")
    this.cmd        = rhs_.cmd;
    this.address    = rhs_.address;
    this.read_write = rhs_.read_write;
    this.status     = rhs_.status;
    this.data       = new[rhs_.data.size()];
    foreach (rhs_.data[i]) this.data[i] = rhs_.data[i];
    this.response   = new[rhs_.response.size()];
    foreach (rhs_.response[i]) this.response[i] = rhs_.response[i];
  endfunction

  // --- do_compare: field-by-field comparison ---
  virtual function bit do_compare(uvm_object rhs, uvm_comparer comparer);
    SPI_Transaction rhs_;
    bit result = super.do_compare(rhs, comparer);
    if (!$cast(rhs_, rhs)) return 0;
    result &= (this.cmd        == rhs_.cmd);
    result &= (this.address    == rhs_.address);
    result &= (this.read_write == rhs_.read_write);
    result &= (this.status     == rhs_.status);
    result &= (this.data.size() == rhs_.data.size());
    if (result)
      foreach (this.data[i])
        result &= (this.data[i] == rhs_.data[i]);
    result &= (this.response.size() == rhs_.response.size());
    if (result)
      foreach (this.response[i])
        result &= (this.response[i] == rhs_.response[i]);
    return result;
  endfunction

  // --- do_print: formatted output ---
  virtual function void do_print(uvm_printer printer);
    super.do_print(printer);
    printer.print_field_int("cmd",        cmd,         8, UVM_HEX);
    printer.print_field_int("address",    address,    24, UVM_HEX);
    printer.print_field_int("read_write", read_write,  1, UVM_BIN);
    printer.print_field_int("status",     status,      1, UVM_BIN);
    printer.print_field_int("data_size",  data.size(), 32, UVM_DEC);
    foreach (data[i])
      printer.print_field_int($sformatf("data[%0d]", i), data[i], 8, UVM_HEX);
    printer.print_field_int("response_size", response.size(), 32, UVM_DEC);
    foreach (response[i])
      printer.print_field_int($sformatf("response[%0d]", i), response[i], 8, UVM_HEX);
  endfunction

  // --- do_pack / do_unpack ---
  virtual function void do_pack(uvm_packer packer);
    super.do_pack(packer);
    packer.pack_field_int(cmd,        8);
    packer.pack_field_int(address,   24);
    packer.pack_field_int(read_write, 1);
    packer.pack_field_int(data.size(), 16);
    foreach (data[i])
      packer.pack_field_int(data[i], 8);
  endfunction

  virtual function void do_unpack(uvm_packer packer);
    int unsigned sz;
    super.do_unpack(packer);
    cmd        = packer.unpack_field_int(8);
    address    = packer.unpack_field_int(24);
    read_write = packer.unpack_field_int(1);
    sz         = packer.unpack_field_int(16);
    data = new[sz];
    foreach (data[i])
      data[i] = packer.unpack_field_int(8);
  endfunction

  // --- convert2string ---
  virtual function string convert2string();
    string s;
    s = $sformatf("SPI %s cmd=0x%02h addr=0x%06h",
                  read_write ? "WR" : "RD", cmd, address);
    if (read_write && data.size() > 0) begin
      s = {s, $sformatf(" data[%0d]={", data.size())};
      foreach (data[i])
        s = {s, $sformatf("%s0x%02h", (i>0) ? "," : "", data[i])};
      s = {s, "}"};
    end
    if (!read_write && response.size() > 0) begin
      s = {s, $sformatf(" rsp[%0d]={", response.size())};
      foreach (response[i])
        s = {s, $sformatf("%s0x%02h", (i>0) ? "," : "", response[i])};
      s = {s, "}"};
    end
    return s;
  endfunction
endclass

// --- Configuration Object ---
class SPI_Config extends uvm_object;
  `uvm_object_utils(SPI_Config)

  bit        cpol;       // clock polarity
  bit        cpha;       // clock phase
  int unsigned clk_div;  // clock divider
  bit [7:0]  slave_select;

  function new(string name = "SPI_Config");
    super.new(name);
    cpol         = 0;
    cpha         = 0;
    clk_div      = 4;
    slave_select = 8'h01;
  endfunction

  virtual function void do_print(uvm_printer printer);
    super.do_print(printer);
    printer.print_field_int("cpol",         cpol,          1, UVM_BIN);
    printer.print_field_int("cpha",         cpha,          1, UVM_BIN);
    printer.print_field_int("clk_div",      clk_div,      32, UVM_DEC);
    printer.print_field_int("slave_select", slave_select,   8, UVM_HEX);
  endfunction

  virtual function string convert2string();
    return $sformatf("SPI_Config: CPOL=%0b CPHA=%0b CLK_DIV=%0d SS=0x%02h",
                     cpol, cpha, clk_div, slave_select);
  endfunction
endclass

// --- Test ---
class uvm_object_demo_test extends uvm_test;
  `uvm_component_utils(uvm_object_demo_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual task run_phase(uvm_phase phase);
    SPI_Transaction txn1, txn2, txn3;
    SPI_Config cfg;
    bit packed_bits[];
    bit result;

    phase.raise_objection(this);

    // --- Create and randomize ---
    `uvm_info("TEST", "=== Create and Randomize ===", UVM_LOW)
    txn1 = SPI_Transaction::type_id::create("txn1");
    if (!txn1.randomize() with { read_write == 1; data.size() == 4; })
      `uvm_fatal("RAND", "Randomization failed")
    `uvm_info("TEST", {"txn1: ", txn1.convert2string()}, UVM_LOW)

    // --- Print with different printers ---
    `uvm_info("TEST", "\n=== Print (table format) ===", UVM_LOW)
    txn1.print();

    // --- Copy ---
    `uvm_info("TEST", "\n=== Copy ===", UVM_LOW)
    txn2 = SPI_Transaction::type_id::create("txn2");
    txn2.copy(txn1);
    `uvm_info("TEST", {"txn2 (copy): ", txn2.convert2string()}, UVM_LOW)

    // --- Compare (should match) ---
    result = txn1.compare(txn2);
    `uvm_info("TEST", $sformatf("txn1 == txn2? %0b (expected 1)", result), UVM_LOW)

    // --- Modify and compare (should differ) ---
    txn2.data[0] = txn2.data[0] ^ 8'hFF;
    result = txn1.compare(txn2);
    `uvm_info("TEST", $sformatf("After modify: txn1 == txn2? %0b (expected 0)", result), UVM_LOW)

    // --- Clone ---
    `uvm_info("TEST", "\n=== Clone ===", UVM_LOW)
    begin
      uvm_object cloned_obj = txn1.clone();
      if (!$cast(txn3, cloned_obj))
        `uvm_fatal("CAST", "Clone cast failed")
      `uvm_info("TEST", {"txn3 (clone): ", txn3.convert2string()}, UVM_LOW)
      txn3.address = 24'hFF_FFFF;
      `uvm_info("TEST", $sformatf("txn1.address=0x%06h txn3.address=0x%06h (independent)",
                                   txn1.address, txn3.address), UVM_LOW)
    end

    // --- Pack and Unpack ---
    `uvm_info("TEST", "\n=== Pack / Unpack ===", UVM_LOW)
    begin
      SPI_Transaction txn_unpacked;
      void'(txn1.pack(packed_bits));
      `uvm_info("TEST", $sformatf("Packed into %0d bits", packed_bits.size()), UVM_LOW)

      txn_unpacked = SPI_Transaction::type_id::create("txn_unpacked");
      void'(txn_unpacked.unpack(packed_bits));
      `uvm_info("TEST", {"Unpacked: ", txn_unpacked.convert2string()}, UVM_LOW)

      result = txn1.compare(txn_unpacked);
      `uvm_info("TEST", $sformatf("Original == Unpacked? %0b (expected 1)", result), UVM_LOW)
    end

    // --- Config Object ---
    `uvm_info("TEST", "\n=== Config Object ===", UVM_LOW)
    cfg = SPI_Config::type_id::create("cfg");
    cfg.cpol    = 1;
    cfg.cpha    = 1;
    cfg.clk_div = 8;
    `uvm_info("TEST", cfg.convert2string(), UVM_LOW)
    cfg.print();

    phase.drop_objection(this);
  endtask
endclass

// --- Top module ---
module tb_uvm_object;
  initial begin
    run_test("uvm_object_demo_test");
  end
endmodule
