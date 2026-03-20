// Functional test sequence using RAL
class ral_functional_sequence extends uvm_sequence;
  `uvm_object_utils(ral_functional_sequence)

  periph_reg_block reg_model;

  function new(string name = "ral_functional_sequence");
    super.new(name);
  endfunction

  task body();
    uvm_status_e   status;
    uvm_reg_data_t data;

    `uvm_info("SEQ", "=== Step 1: Verify reset values ===", UVM_LOW)
    reg_model.CTRL.read(status, data);
    if (data != 32'h0)
      `uvm_error("SEQ", $sformatf("CTRL reset value mismatch: got 0x%08h, expected 0x0", data))
    else
      `uvm_info("SEQ", "CTRL reset value OK", UVM_MEDIUM)

    reg_model.STATUS.read(status, data);
    `uvm_info("SEQ", $sformatf("STATUS after reset: 0x%08h", data), UVM_MEDIUM)

    `uvm_info("SEQ", "=== Step 2: Write data and enable processing ===", UVM_LOW)
    reg_model.DATA_IN.write(status, 32'hCAFE_BABE);
    if (status != UVM_IS_OK)
      `uvm_error("SEQ", "DATA_IN write failed")

    // Enable with mode=0 (pass-through)
    reg_model.CTRL.write(status, 32'h0000_0001);

    // Wait for processing
    #100;

    `uvm_info("SEQ", "=== Step 3: Read output ===", UVM_LOW)
    reg_model.DATA_OUT.read(status, data);
    `uvm_info("SEQ", $sformatf("DATA_OUT = 0x%08h (expected 0xCAFE_BABE for pass-through)", data), UVM_LOW)

    if (data != 32'hCAFE_BABE)
      `uvm_error("SEQ", $sformatf("DATA_OUT mismatch: got 0x%08h", data))

    `uvm_info("SEQ", "=== Step 4: Test mode=1 (increment) ===", UVM_LOW)
    reg_model.DATA_IN.write(status, 32'h0000_00FF);
    reg_model.CTRL.mode.set(2'b01);
    reg_model.CTRL.enable.set(1'b1);
    reg_model.CTRL.update(status);

    #100;
    reg_model.DATA_OUT.read(status, data);
    `uvm_info("SEQ", $sformatf("DATA_OUT = 0x%08h (expected 0x00000100 for increment)", data), UVM_LOW)

    `uvm_info("SEQ", "=== Step 5: Test mode=3 (invert) ===", UVM_LOW)
    reg_model.DATA_IN.write(status, 32'hAAAA_5555);
    reg_model.CTRL.mode.set(2'b11);
    reg_model.CTRL.enable.set(1'b1);
    reg_model.CTRL.update(status);

    #100;
    reg_model.DATA_OUT.read(status, data);
    `uvm_info("SEQ", $sformatf("DATA_OUT = 0x%08h (expected 0x5555AAAA for invert)", data), UVM_LOW)

    `uvm_info("SEQ", "=== Step 6: Check status register ===", UVM_LOW)
    reg_model.STATUS.read(status, data);
    `uvm_info("SEQ", $sformatf("STATUS = 0x%08h (done bit should be set)", data), UVM_LOW)

    `uvm_info("SEQ", "Functional sequence complete", UVM_LOW)
  endtask
endclass

// Read-write test sequence
class ral_rw_sequence extends uvm_sequence;
  `uvm_object_utils(ral_rw_sequence)

  periph_reg_block reg_model;

  function new(string name = "ral_rw_sequence");
    super.new(name);
  endfunction

  task body();
    uvm_status_e   status;
    uvm_reg_data_t wr_data, rd_data;

    `uvm_info("SEQ", "Testing CTRL register read-write", UVM_LOW)
    wr_data = 32'h0000_000F;
    reg_model.CTRL.write(status, wr_data);
    reg_model.CTRL.read(status, rd_data);
    if ((rd_data & 32'h0000_000F) != (wr_data & 32'h0000_000F))
      `uvm_error("SEQ", $sformatf("CTRL RW fail: wrote 0x%08h, read 0x%08h", wr_data, rd_data))
    else
      `uvm_info("SEQ", "CTRL RW pass", UVM_MEDIUM)

    `uvm_info("SEQ", "Testing DATA_IN register read-write", UVM_LOW)
    for (int i = 0; i < 5; i++) begin
      wr_data = $urandom();
      reg_model.DATA_IN.write(status, wr_data);
      reg_model.DATA_IN.read(status, rd_data);
      if (rd_data != wr_data)
        `uvm_error("SEQ", $sformatf("DATA_IN RW fail: wrote 0x%08h, read 0x%08h", wr_data, rd_data))
      else
        `uvm_info("SEQ", $sformatf("DATA_IN RW pass: 0x%08h", rd_data), UVM_MEDIUM)
    end

    `uvm_info("SEQ", "Testing STATUS register (read-only)", UVM_LOW)
    reg_model.STATUS.read(status, rd_data);
    `uvm_info("SEQ", $sformatf("STATUS = 0x%08h", rd_data), UVM_MEDIUM)

    `uvm_info("SEQ", "RW sequence complete", UVM_LOW)
  endtask
endclass
