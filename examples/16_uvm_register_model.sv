// UVM Register Abstraction Layer (RAL) Example
//
// Demonstrates:
//   - uvm_reg_field: individual bit-fields within a register
//   - uvm_reg: complete register with multiple fields
//   - uvm_reg_block: collection of registers with an address map
//   - uvm_reg_adapter: converts RAL operations to bus transactions
//   - uvm_reg_predictor: auto-updates the model from observed traffic
//   - Front-door and back-door access methods
//   - Built-in mirror/update/predict operations

`ifndef UVM_REG_MODEL_SV
`define UVM_REG_MODEL_SV

`include "uvm_macros.svh"
import uvm_pkg::*;


// ═══════════════════════════════════════════════════════════════
//  Register Definitions
// ═══════════════════════════════════════════════════════════════

// ── Control Register (offset 0x00) ──
//  [0]    : ENABLE  (RW) — peripheral enable
//  [2:1]  : MODE    (RW) — operating mode
//  [7:3]  : reserved
//  [15:8] : IRQ_MASK(RW) — interrupt mask bits
//  [31:16]: reserved

class ctrl_reg extends uvm_reg;
  `uvm_object_utils(ctrl_reg)

  rand uvm_reg_field enable;
  rand uvm_reg_field mode;
  rand uvm_reg_field irq_mask;

  function new(string name = "ctrl_reg");
    super.new(name, 32, UVM_NO_COVERAGE);
  endfunction

  virtual function void build();
    enable   = uvm_reg_field::type_id::create("enable");
    mode     = uvm_reg_field::type_id::create("mode");
    irq_mask = uvm_reg_field::type_id::create("irq_mask");

    //            parent size lsb access volatile reset has_reset rand accessible
    enable.configure  (this, 1,  0,  "RW", 0, 1'h0,   1, 1, 0);
    mode.configure    (this, 2,  1,  "RW", 0, 2'h0,   1, 1, 0);
    irq_mask.configure(this, 8,  8,  "RW", 0, 8'hFF,  1, 1, 0);
  endfunction
endclass


// ── Status Register (offset 0x04) ──
//  [0]   : BUSY    (RO)  — peripheral busy
//  [1]   : DONE    (W1C) — operation complete (write 1 to clear)
//  [2]   : ERROR   (RO)  — error flag
//  [7:3] : reserved
//  [15:8]: IRQ_STAT(RO)  — pending interrupt status

class status_reg extends uvm_reg;
  `uvm_object_utils(status_reg)

  rand uvm_reg_field busy;
  rand uvm_reg_field done;
  rand uvm_reg_field error_flag;
  rand uvm_reg_field irq_status;

  function new(string name = "status_reg");
    super.new(name, 32, UVM_NO_COVERAGE);
  endfunction

  virtual function void build();
    busy       = uvm_reg_field::type_id::create("busy");
    done       = uvm_reg_field::type_id::create("done");
    error_flag = uvm_reg_field::type_id::create("error_flag");
    irq_status = uvm_reg_field::type_id::create("irq_status");

    busy.configure      (this, 1, 0, "RO",  1, 1'h0, 1, 0, 0);
    done.configure      (this, 1, 1, "W1C", 1, 1'h0, 1, 0, 0);
    error_flag.configure(this, 1, 2, "RO",  1, 1'h0, 1, 0, 0);
    irq_status.configure(this, 8, 8, "RO",  1, 8'h0, 1, 0, 0);
  endfunction
endclass


// ── Data Register (offset 0x08) ──
//  [31:0]: DATA (RW) — data read/write register

class data_reg extends uvm_reg;
  `uvm_object_utils(data_reg)

  rand uvm_reg_field data_field;

  function new(string name = "data_reg");
    super.new(name, 32, UVM_NO_COVERAGE);
  endfunction

  virtual function void build();
    data_field = uvm_reg_field::type_id::create("data_field");
    data_field.configure(this, 32, 0, "RW", 0, 32'h0, 1, 1, 1);
  endfunction
endclass


// ── Address Register (offset 0x0C) ──
//  [31:0]: ADDR (RW) — target address

class addr_reg extends uvm_reg;
  `uvm_object_utils(addr_reg)

  rand uvm_reg_field addr_field;

  function new(string name = "addr_reg");
    super.new(name, 32, UVM_NO_COVERAGE);
  endfunction

  virtual function void build();
    addr_field = uvm_reg_field::type_id::create("addr_field");
    addr_field.configure(this, 32, 0, "RW", 0, 32'h0, 1, 1, 1);
  endfunction
endclass


// ═══════════════════════════════════════════════════════════════
//  Register Block
//  Groups all registers and creates an address map.
// ═══════════════════════════════════════════════════════════════

class peripheral_reg_block extends uvm_reg_block;
  `uvm_object_utils(peripheral_reg_block)

  rand ctrl_reg   ctrl;
  rand status_reg status;
  rand data_reg   data;
  rand addr_reg   address;

  uvm_reg_map default_map;

  function new(string name = "peripheral_reg_block");
    super.new(name, UVM_NO_COVERAGE);
  endfunction

  virtual function void build();
    // Create registers
    ctrl    = ctrl_reg::type_id::create("ctrl");
    status  = status_reg::type_id::create("status");
    data    = data_reg::type_id::create("data");
    address = addr_reg::type_id::create("address");

    // Configure registers (parent block, reg file, hdl path)
    ctrl.configure(this, null, "");
    status.configure(this, null, "");
    data.configure(this, null, "");
    address.configure(this, null, "");

    // Build register internals (fields)
    ctrl.build();
    status.build();
    data.build();
    address.build();

    // Create address map
    //   name, base_addr, n_bytes (bus width), endianness, byte_addressing
    default_map = create_map("default_map", 'h0, 4, UVM_LITTLE_ENDIAN, 1);

    // Add registers to map with their offsets
    default_map.add_reg(ctrl,    'h00, "RW");
    default_map.add_reg(status,  'h04, "RO");
    default_map.add_reg(data,    'h08, "RW");
    default_map.add_reg(address, 'h0C, "RW");

    // Lock the model — no further structural changes allowed
    lock_model();
  endfunction
endclass


// ═══════════════════════════════════════════════════════════════
//  Register Adapter
//  Converts between abstract uvm_reg_bus_op and concrete
//  apb_transaction objects used on the bus.
// ═══════════════════════════════════════════════════════════════

class apb_reg_adapter extends uvm_reg_adapter;
  `uvm_object_utils(apb_reg_adapter)

  function new(string name = "apb_reg_adapter");
    super.new(name);
    supports_byte_enable = 0;
    provides_responses   = 0;
  endfunction

  // Convert a RAL operation into a bus transaction
  virtual function uvm_sequence_item reg2bus(const ref uvm_reg_bus_op rw);
    apb_transaction txn = apb_transaction::type_id::create("reg2bus_txn");
    txn.addr      = rw.addr;
    txn.operation = (rw.kind == UVM_WRITE) ? APB_WRITE : APB_READ;
    txn.data      = rw.data;
    txn.strobe    = 4'b1111;
    return txn;
  endfunction

  // Convert a bus transaction back into a RAL operation result
  virtual function void bus2reg(uvm_sequence_item bus_item,
                                ref uvm_reg_bus_op rw);
    apb_transaction txn;
    if (!$cast(txn, bus_item)) begin
      `uvm_fatal("CAST", "bus2reg cast failed — wrong transaction type")
      return;
    end
    rw.addr   = txn.addr;
    rw.data   = (txn.operation == APB_READ) ? txn.read_data : txn.data;
    rw.kind   = (txn.operation == APB_WRITE) ? UVM_WRITE : UVM_READ;
    rw.status = txn.slv_error ? UVM_NOT_OK : UVM_IS_OK;
  endfunction
endclass


// ═══════════════════════════════════════════════════════════════
//  Register Test Sequence
//  Demonstrates common RAL access patterns.
// ═══════════════════════════════════════════════════════════════

class reg_test_sequence extends uvm_reg_sequence;
  `uvm_object_utils(reg_test_sequence)

  peripheral_reg_block reg_model;

  function new(string name = "reg_test_sequence");
    super.new(name);
  endfunction

  virtual task body();
    uvm_status_e   status;
    uvm_reg_data_t read_data;

    if (reg_model == null)
      `uvm_fatal("NOREG", "Register model handle is null")

    `uvm_info(get_type_name(), "Starting register tests", UVM_LOW)

    // ── Test 1: Reset value check ──
    `uvm_info(get_type_name(), "--- Reset Value Check ---", UVM_LOW)
    reg_model.ctrl.mirror(status, UVM_CHECK);
    if (status != UVM_IS_OK)
      `uvm_error(get_type_name(), "CTRL register reset value mismatch")

    // ── Test 2: Write and read-back ──
    `uvm_info(get_type_name(), "--- Write/Readback Test ---", UVM_LOW)

    // Write using full register
    reg_model.ctrl.write(status, 32'h0000_FF07);
    if (status != UVM_IS_OK)
      `uvm_error(get_type_name(), "CTRL write failed")

    // Read back
    reg_model.ctrl.read(status, read_data);
    `uvm_info(get_type_name(),
      $sformatf("CTRL read back: 0x%08h", read_data), UVM_LOW)

    // ── Test 3: Field-level access ──
    `uvm_info(get_type_name(), "--- Field-Level Access ---", UVM_LOW)

    // Modify individual fields in the desired value
    reg_model.ctrl.enable.set(1'b1);
    reg_model.ctrl.mode.set(2'b10);
    reg_model.ctrl.irq_mask.set(8'hA5);

    // Write only if desired != mirrored (efficient partial update)
    reg_model.ctrl.update(status);
    if (status != UVM_IS_OK)
      `uvm_error(get_type_name(), "CTRL update failed")

    // Verify by reading back
    reg_model.ctrl.mirror(status, UVM_CHECK);

    // Read individual field values from mirror
    `uvm_info(get_type_name(), $sformatf(
      "  enable=%0b  mode=%0b  irq_mask=0x%02h",
      reg_model.ctrl.enable.get_mirrored_value(),
      reg_model.ctrl.mode.get_mirrored_value(),
      reg_model.ctrl.irq_mask.get_mirrored_value()),
      UVM_LOW)

    // ── Test 4: Data register write/read ──
    `uvm_info(get_type_name(), "--- Data Register Test ---", UVM_LOW)
    reg_model.data.write(status, 32'hDEAD_BEEF);
    reg_model.data.read(status, read_data);
    if (read_data !== 32'hDEAD_BEEF)
      `uvm_error(get_type_name(),
        $sformatf("DATA mismatch: exp=0xDEADBEEF act=0x%08h", read_data))

    // ── Test 5: Walking ones on address register ──
    `uvm_info(get_type_name(), "--- Walking Ones Test ---", UVM_LOW)
    for (int i = 0; i < 32; i++) begin
      uvm_reg_data_t pattern = 1 << i;
      reg_model.address.write(status, pattern);
      reg_model.address.read(status, read_data);
      if (read_data !== pattern)
        `uvm_error(get_type_name(),
          $sformatf("Walking ones bit %0d: exp=0x%08h act=0x%08h",
                    i, pattern, read_data))
    end

    // ── Test 6: Reset and verify ──
    `uvm_info(get_type_name(), "--- Post-Reset Check ---", UVM_LOW)
    reg_model.reset();
    // After model reset, mirror all registers from hardware
    reg_model.ctrl.mirror(status, UVM_CHECK);
    reg_model.data.mirror(status, UVM_CHECK);
    reg_model.address.mirror(status, UVM_CHECK);

    `uvm_info(get_type_name(), "Register tests complete", UVM_LOW)
  endtask
endclass

`endif
