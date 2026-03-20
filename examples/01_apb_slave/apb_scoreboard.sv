// APB Scoreboard — verifies DUT correctness by modeling expected memory behavior
class apb_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(apb_scoreboard)

  uvm_analysis_imp #(apb_seq_item, apb_scoreboard) analysis_export;

  // Reference memory model
  bit [31:0] ref_mem [bit [31:0]];

  int pass_count = 0;
  int fail_count = 0;
  int write_count = 0;
  int read_count = 0;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    analysis_export = new("analysis_export", this);
  endfunction

  function void write(apb_seq_item tr);
    if (tr.slverr) begin
      `uvm_info("SCB", $sformatf("Transaction with error: %s", tr.convert2string()), UVM_MEDIUM)
      return;
    end

    if (tr.write) begin
      ref_mem[tr.addr] = tr.data;
      write_count++;
      `uvm_info("SCB", $sformatf("Stored: mem[0x%08h] = 0x%08h", tr.addr, tr.data), UVM_HIGH)
    end else begin
      read_count++;
      if (ref_mem.exists(tr.addr)) begin
        if (tr.rdata === ref_mem[tr.addr]) begin
          pass_count++;
          `uvm_info("SCB", $sformatf("PASS: addr=0x%08h expected=0x%08h got=0x%08h",
                    tr.addr, ref_mem[tr.addr], tr.rdata), UVM_MEDIUM)
        end else begin
          fail_count++;
          `uvm_error("SCB", $sformatf("FAIL: addr=0x%08h expected=0x%08h got=0x%08h",
                     tr.addr, ref_mem[tr.addr], tr.rdata))
        end
      end else begin
        if (tr.rdata === 32'h0) begin
          pass_count++;
          `uvm_info("SCB", $sformatf("PASS: uninitialized addr=0x%08h returned 0x00000000",
                    tr.addr), UVM_MEDIUM)
        end else begin
          fail_count++;
          `uvm_error("SCB", $sformatf("FAIL: uninitialized addr=0x%08h expected=0x00000000 got=0x%08h",
                     tr.addr, tr.rdata))
        end
      end
    end
  endfunction

  function void report_phase(uvm_phase phase);
    `uvm_info("SCB", "============================================", UVM_LOW)
    `uvm_info("SCB", "         SCOREBOARD SUMMARY                 ", UVM_LOW)
    `uvm_info("SCB", "============================================", UVM_LOW)
    `uvm_info("SCB", $sformatf("  Total Writes : %0d", write_count), UVM_LOW)
    `uvm_info("SCB", $sformatf("  Total Reads  : %0d", read_count), UVM_LOW)
    `uvm_info("SCB", $sformatf("  Passed       : %0d", pass_count), UVM_LOW)
    `uvm_info("SCB", $sformatf("  Failed       : %0d", fail_count), UVM_LOW)
    `uvm_info("SCB", "============================================", UVM_LOW)
    if (fail_count == 0)
      `uvm_info("SCB", "*** TEST PASSED ***", UVM_NONE)
    else
      `uvm_error("SCB", "*** TEST FAILED ***")
  endfunction

endclass
