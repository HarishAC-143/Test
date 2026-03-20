// AXI-Lite Scoreboard — tracks register state and verifies read data
class axi_lite_scoreboard extends uvm_scoreboard;

  `uvm_component_utils(axi_lite_scoreboard)

  uvm_analysis_imp #(axi_lite_txn, axi_lite_scoreboard) analysis_export;

  // Reference register model
  bit [31:0] ref_regs [4];

  int write_count;
  int read_count;
  int pass_count;
  int fail_count;
  int resp_error_count;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    write_count     = 0;
    read_count      = 0;
    pass_count      = 0;
    fail_count      = 0;
    resp_error_count = 0;
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    analysis_export = new("analysis_export", this);
    foreach (ref_regs[i])
      ref_regs[i] = 32'd0;
  endfunction

  virtual function void write(axi_lite_txn txn);
    int reg_idx = txn.addr[3:2];

    if (txn.dir == AXI_WRITE) begin
      write_count++;

      // Check response
      if (txn.resp != AXI_OKAY && reg_idx < 4) begin
        resp_error_count++;
        `uvm_error("SB", $sformatf("Write got unexpected response %s for valid addr 0x%08h",
                   txn.resp.name(), txn.addr))
      end

      // Update reference model with byte strobes
      if (reg_idx < 4) begin
        if (txn.strb[0]) ref_regs[reg_idx][ 7: 0] = txn.data[ 7: 0];
        if (txn.strb[1]) ref_regs[reg_idx][15: 8] = txn.data[15: 8];
        if (txn.strb[2]) ref_regs[reg_idx][23:16] = txn.data[23:16];
        if (txn.strb[3]) ref_regs[reg_idx][31:24] = txn.data[31:24];
        `uvm_info("SB", $sformatf("REF WRITE: reg[%0d] = 0x%08h (strb=%04b)",
                  reg_idx, ref_regs[reg_idx], txn.strb), UVM_HIGH)
      end

    end else begin
      read_count++;

      // Check response
      if (txn.resp != AXI_OKAY && reg_idx < 4) begin
        resp_error_count++;
        `uvm_error("SB", $sformatf("Read got unexpected response %s for valid addr 0x%08h",
                   txn.resp.name(), txn.addr))
      end

      // Compare read data with reference
      if (reg_idx < 4) begin
        if (txn.data === ref_regs[reg_idx]) begin
          pass_count++;
          `uvm_info("SB", $sformatf("PASS: READ reg[%0d] = 0x%08h",
                    reg_idx, txn.data), UVM_HIGH)
        end else begin
          fail_count++;
          `uvm_error("SB", $sformatf("FAIL: READ reg[%0d] = 0x%08h (expected 0x%08h)",
                     reg_idx, txn.data, ref_regs[reg_idx]))
        end
      end
    end
  endfunction

  virtual function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info("SB", "============================================", UVM_NONE)
    `uvm_info("SB", "  AXI-Lite Scoreboard Results:", UVM_NONE)
    `uvm_info("SB", $sformatf("    Writes:       %0d", write_count), UVM_NONE)
    `uvm_info("SB", $sformatf("    Reads:        %0d", read_count), UVM_NONE)
    `uvm_info("SB", $sformatf("    Read PASS:    %0d", pass_count), UVM_NONE)
    `uvm_info("SB", $sformatf("    Read FAIL:    %0d", fail_count), UVM_NONE)
    `uvm_info("SB", $sformatf("    Resp Errors:  %0d", resp_error_count), UVM_NONE)
    `uvm_info("SB", "============================================", UVM_NONE)
  endfunction

endclass
