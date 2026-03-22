// =============================================================================
// Example 11: UVM Register Abstraction Layer (RAL)
// Demonstrates: uvm_reg, uvm_reg_field, uvm_reg_block, uvm_reg_map,
//               front-door access, field-level read/write/set/get,
//               mirror, update, predict, reset.
// =============================================================================

`include "uvm_macros.svh"
import uvm_pkg::*;

// ===================================================================
// REGISTER DEFINITIONS
// ===================================================================

// --- Control Register ---
// Bits [0]   : enable      (RW)
// Bits [2:1] : mode        (RW)
// Bits [7:3] : reserved
// Bits [15:8]: prescaler   (RW)
// Bits [31:16]: reserved
class ctrl_reg extends uvm_reg;
  `uvm_object_utils(ctrl_reg)

  rand uvm_reg_field enable;
  rand uvm_reg_field mode;
  rand uvm_reg_field prescaler;

  function new(string name = "ctrl_reg");
    super.new(name, 32, UVM_NO_COVERAGE);
  endfunction

  virtual function void build();
    enable    = uvm_reg_field::type_id::create("enable");
    mode      = uvm_reg_field::type_id::create("mode");
    prescaler = uvm_reg_field::type_id::create("prescaler");

    //                 parent, size, lsb, access, volatile, reset, has_reset, is_rand, individually_accessible
    enable.configure   (this,   1,    0,  "RW",    0,  1'b0,    1,    1,    0);
    mode.configure     (this,   2,    1,  "RW",    0,  2'b00,   1,    1,    0);
    prescaler.configure(this,   8,    8,  "RW",    0,  8'h01,   1,    1,    0);
  endfunction
endclass

// --- Status Register ---
// Bits [0]   : busy        (RO)
// Bits [1]   : done        (RO)
// Bits [2]   : error       (RO)
// Bits [7:3] : reserved
// Bits [15:8]: fifo_level  (RO)
// Bits [31:16]: reserved
class status_reg extends uvm_reg;
  `uvm_object_utils(status_reg)

  rand uvm_reg_field busy;
  rand uvm_reg_field done;
  rand uvm_reg_field error;
  rand uvm_reg_field fifo_level;

  function new(string name = "status_reg");
    super.new(name, 32, UVM_NO_COVERAGE);
  endfunction

  virtual function void build();
    busy       = uvm_reg_field::type_id::create("busy");
    done       = uvm_reg_field::type_id::create("done");
    error      = uvm_reg_field::type_id::create("error");
    fifo_level = uvm_reg_field::type_id::create("fifo_level");

    busy.configure      (this, 1, 0, "RO", 1, 1'b0, 1, 0, 0);
    done.configure      (this, 1, 1, "RO", 1, 1'b0, 1, 0, 0);
    error.configure     (this, 1, 2, "RO", 1, 1'b0, 1, 0, 0);
    fifo_level.configure(this, 8, 8, "RO", 1, 8'h00, 1, 0, 0);
  endfunction
endclass

// --- Interrupt Register ---
// Bits [7:0] : irq_status  (W1C — write-1-to-clear)
// Bits [15:8]: irq_enable  (RW)
// Bits [31:16]: reserved
class intr_reg extends uvm_reg;
  `uvm_object_utils(intr_reg)

  rand uvm_reg_field irq_status;
  rand uvm_reg_field irq_enable;

  function new(string name = "intr_reg");
    super.new(name, 32, UVM_NO_COVERAGE);
  endfunction

  virtual function void build();
    irq_status = uvm_reg_field::type_id::create("irq_status");
    irq_enable = uvm_reg_field::type_id::create("irq_enable");

    irq_status.configure(this, 8, 0, "W1C", 1, 8'h00, 1, 0, 0);
    irq_enable.configure(this, 8, 8, "RW",  0, 8'h00, 1, 1, 0);
  endfunction
endclass

// --- Data Register ---
// Bits [31:0]: data (RW)
class data_reg extends uvm_reg;
  `uvm_object_utils(data_reg)

  rand uvm_reg_field data;

  function new(string name = "data_reg");
    super.new(name, 32, UVM_NO_COVERAGE);
  endfunction

  virtual function void build();
    data = uvm_reg_field::type_id::create("data");
    data.configure(this, 32, 0, "RW", 0, 32'h0000_0000, 1, 1, 0);
  endfunction
endclass

// ===================================================================
// REGISTER BLOCK
// ===================================================================
class peripheral_reg_block extends uvm_reg_block;
  `uvm_object_utils(peripheral_reg_block)

  rand ctrl_reg   ctrl;
  rand status_reg status;
  rand intr_reg   intr;
  rand data_reg   tx_data;
  rand data_reg   rx_data;

  uvm_reg_map default_map;

  function new(string name = "peripheral_reg_block");
    super.new(name, UVM_NO_COVERAGE);
  endfunction

  virtual function void build();
    // Create registers
    ctrl    = ctrl_reg::type_id::create("ctrl");
    status  = status_reg::type_id::create("status");
    intr    = intr_reg::type_id::create("intr");
    tx_data = data_reg::type_id::create("tx_data");
    rx_data = data_reg::type_id::create("rx_data");

    // Configure parent
    ctrl.configure(this, null, "");
    status.configure(this, null, "");
    intr.configure(this, null, "");
    tx_data.configure(this, null, "");
    rx_data.configure(this, null, "");

    // Build fields
    ctrl.build();
    status.build();
    intr.build();
    tx_data.build();
    rx_data.build();

    // Create address map
    default_map = create_map("default_map",
                             'h0,                // base address
                             4,                  // bus width in bytes
                             UVM_LITTLE_ENDIAN);

    // Add registers to map
    default_map.add_reg(ctrl,    'h00, "RW");
    default_map.add_reg(status,  'h04, "RO");
    default_map.add_reg(intr,    'h08, "RW");
    default_map.add_reg(tx_data, 'h0C, "RW");
    default_map.add_reg(rx_data, 'h10, "RO");

    lock_model();
  endfunction
endclass

// ===================================================================
// DEMO TEST (standalone — no DUT, demonstrates API only)
// ===================================================================
class ral_demo_test extends uvm_test;
  `uvm_component_utils(ral_demo_test)

  peripheral_reg_block reg_block;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    reg_block = peripheral_reg_block::type_id::create("reg_block");
    reg_block.build();
  endfunction

  virtual task run_phase(uvm_phase phase);
    phase.raise_objection(this);

    `uvm_info("RAL", "\n=== Register Block Structure ===", UVM_LOW)
    begin
      uvm_reg regs[$];
      reg_block.get_registers(regs);
      foreach (regs[i])
        `uvm_info("RAL", $sformatf("  Register: %-10s  Offset: 0x%04h  Access: %s  Reset: 0x%08h",
                  regs[i].get_name(),
                  regs[i].get_offset(),
                  regs[i].get_access(),
                  regs[i].get_reset()),
                  UVM_LOW)
    end

    `uvm_info("RAL", "\n=== Field Details ===", UVM_LOW)
    begin
      uvm_reg_field fields[$];
      reg_block.ctrl.get_fields(fields);
      foreach (fields[i])
        `uvm_info("RAL", $sformatf("  ctrl.%-12s  size=%0d  lsb=%0d  access=%s  reset=0x%0h",
                  fields[i].get_name(),
                  fields[i].get_n_bits(),
                  fields[i].get_lsb_pos(),
                  fields[i].get_access(),
                  fields[i].get_reset()),
                  UVM_LOW)
    end

    `uvm_info("RAL", "\n=== Set/Get (desired value, no DUT access) ===", UVM_LOW)
    begin
      reg_block.ctrl.enable.set(1);
      reg_block.ctrl.mode.set(2'b11);
      reg_block.ctrl.prescaler.set(8'hAA);
      `uvm_info("RAL", $sformatf("ctrl desired: 0x%08h", reg_block.ctrl.get()), UVM_LOW)
      `uvm_info("RAL", $sformatf("  enable    = %0d", reg_block.ctrl.enable.get()), UVM_LOW)
      `uvm_info("RAL", $sformatf("  mode      = %0d", reg_block.ctrl.mode.get()), UVM_LOW)
      `uvm_info("RAL", $sformatf("  prescaler = 0x%02h", reg_block.ctrl.prescaler.get()), UVM_LOW)
    end

    `uvm_info("RAL", "\n=== Predict (simulate DUT writes) ===", UVM_LOW)
    begin
      reg_block.ctrl.predict(32'h0000_AA07);
      `uvm_info("RAL", $sformatf("ctrl mirrored: 0x%08h", reg_block.ctrl.get_mirrored_value()), UVM_LOW)
      `uvm_info("RAL", $sformatf("  enable    = %0d", reg_block.ctrl.enable.get_mirrored_value()), UVM_LOW)
      `uvm_info("RAL", $sformatf("  mode      = %0d", reg_block.ctrl.mode.get_mirrored_value()), UVM_LOW)
      `uvm_info("RAL", $sformatf("  prescaler = 0x%02h", reg_block.ctrl.prescaler.get_mirrored_value()), UVM_LOW)
    end

    `uvm_info("RAL", "\n=== Reset ===", UVM_LOW)
    begin
      `uvm_info("RAL", $sformatf("Before reset: ctrl=0x%08h", reg_block.ctrl.get_mirrored_value()), UVM_LOW)
      reg_block.reset();
      `uvm_info("RAL", $sformatf("After reset:  ctrl=0x%08h (expected 0x00000100)",
                reg_block.ctrl.get_mirrored_value()), UVM_LOW)
    end

    `uvm_info("RAL", "\n=== Register Randomization ===", UVM_LOW)
    begin
      if (!reg_block.ctrl.randomize())
        `uvm_warning("RAL", "ctrl randomize failed")
      `uvm_info("RAL", $sformatf("Random ctrl desired: 0x%08h", reg_block.ctrl.get()), UVM_LOW)
    end

    `uvm_info("RAL", "\n=== Address Map ===", UVM_LOW)
    begin
      uvm_reg rg;
      rg = reg_block.default_map.get_reg_by_offset('h00);
      if (rg != null) `uvm_info("RAL", $sformatf("Offset 0x00 -> %s", rg.get_name()), UVM_LOW)
      rg = reg_block.default_map.get_reg_by_offset('h04);
      if (rg != null) `uvm_info("RAL", $sformatf("Offset 0x04 -> %s", rg.get_name()), UVM_LOW)
      rg = reg_block.default_map.get_reg_by_offset('h08);
      if (rg != null) `uvm_info("RAL", $sformatf("Offset 0x08 -> %s", rg.get_name()), UVM_LOW)
      rg = reg_block.default_map.get_reg_by_offset('h0C);
      if (rg != null) `uvm_info("RAL", $sformatf("Offset 0x0C -> %s", rg.get_name()), UVM_LOW)
      rg = reg_block.default_map.get_reg_by_offset('h10);
      if (rg != null) `uvm_info("RAL", $sformatf("Offset 0x10 -> %s", rg.get_name()), UVM_LOW)
    end

    phase.drop_objection(this);
  endtask
endclass

// --- Top module ---
module tb_ral;
  initial begin
    run_test("ral_demo_test");
  end
endmodule
