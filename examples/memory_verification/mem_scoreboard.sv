// Memory Scoreboard — contains a reference model and checks all reads
class mem_scoreboard extends uvm_scoreboard;

  `uvm_component_utils(mem_scoreboard)

  uvm_analysis_imp #(mem_txn, mem_scoreboard) analysis_export;

  // Reference memory model
  bit [7:0] ref_mem [256];
  bit       ref_written [256];  // track which addresses have been written

  int pass_count;
  int fail_count;
  int write_count;
  int read_count;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    pass_count  = 0;
    fail_count  = 0;
    write_count = 0;
    read_count  = 0;
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    analysis_export = new("analysis_export", this);
    // Initialize reference model
    foreach (ref_mem[i]) begin
      ref_mem[i] = 8'd0;
      ref_written[i] = 0;
    end
  endfunction

  virtual function void write(mem_txn txn);
    if (txn.op == MEM_WRITE) begin
      // Update reference model
      ref_mem[txn.addr] = txn.wdata;
      ref_written[txn.addr] = 1;
      write_count++;
      `uvm_info("SB", $sformatf("REF WRITE: mem[0x%02h] = 0x%02h",
                txn.addr, txn.wdata), UVM_HIGH)
    end else begin
      // Compare read data against reference
      read_count++;
      if (ref_written[txn.addr]) begin
        if (txn.rdata === ref_mem[txn.addr]) begin
          pass_count++;
          `uvm_info("SB", $sformatf("PASS: READ mem[0x%02h] = 0x%02h (expected 0x%02h)",
                    txn.addr, txn.rdata, ref_mem[txn.addr]), UVM_HIGH)
        end else begin
          fail_count++;
          `uvm_error("SB", $sformatf("FAIL: READ mem[0x%02h] = 0x%02h (expected 0x%02h)",
                     txn.addr, txn.rdata, ref_mem[txn.addr]))
        end
      end else begin
        `uvm_info("SB", $sformatf("INFO: READ from uninitialized addr 0x%02h, got 0x%02h",
                  txn.addr, txn.rdata), UVM_MEDIUM)
      end
    end
  endfunction

  virtual function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info("SB", "============================================", UVM_NONE)
    `uvm_info("SB", "  Memory Scoreboard Results:", UVM_NONE)
    `uvm_info("SB", $sformatf("    Writes:   %0d", write_count), UVM_NONE)
    `uvm_info("SB", $sformatf("    Reads:    %0d", read_count), UVM_NONE)
    `uvm_info("SB", $sformatf("    PASSED:   %0d", pass_count), UVM_NONE)
    `uvm_info("SB", $sformatf("    FAILED:   %0d", fail_count), UVM_NONE)
    `uvm_info("SB", "============================================", UVM_NONE)
  endfunction

endclass
