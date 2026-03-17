// Memory Scoreboard — maintains a reference model and checks reads
class mem_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(mem_scoreboard)

  uvm_analysis_imp #(mem_transaction, mem_scoreboard) analysis_export;

  // Reference model: associative array mirroring the DUT memory
  bit [MEM_DATA_WIDTH-1:0] ref_mem [bit [MEM_ADDR_WIDTH-1:0]];

  int write_count = 0;
  int read_count  = 0;
  int pass_count  = 0;
  int fail_count  = 0;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    analysis_export = new("analysis_export", this);
  endfunction

  function void write(mem_transaction txn);
    if (txn.write) begin
      // Write operation: update reference model
      ref_mem[txn.addr] = txn.wdata;
      write_count++;
      `uvm_info("SCB", $sformatf("REF WRITE: addr=0x%02h data=0x%08h", txn.addr, txn.wdata), UVM_HIGH)
    end else begin
      // Read operation: compare against reference model
      read_count++;
      if (ref_mem.exists(txn.addr)) begin
        if (txn.rdata === ref_mem[txn.addr]) begin
          pass_count++;
          `uvm_info("SCB", $sformatf("PASS: addr=0x%02h data=0x%08h", txn.addr, txn.rdata), UVM_HIGH)
        end else begin
          fail_count++;
          `uvm_error("SCB", $sformatf("FAIL: addr=0x%02h expected=0x%08h got=0x%08h",
                                       txn.addr, ref_mem[txn.addr], txn.rdata))
        end
      end else begin
        `uvm_info("SCB", $sformatf("READ from uninitialized addr=0x%02h (data=0x%08h) — skipping check",
                                   txn.addr, txn.rdata), UVM_MEDIUM)
      end
    end
  endfunction

  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info("SCB", "================================================", UVM_NONE)
    `uvm_info("SCB", "  Memory Scoreboard Results", UVM_NONE)
    `uvm_info("SCB", $sformatf("  Writes: %0d | Reads: %0d", write_count, read_count), UVM_NONE)
    `uvm_info("SCB", $sformatf("  Passed: %0d | Failed: %0d", pass_count, fail_count), UVM_NONE)
    `uvm_info("SCB", "================================================", UVM_NONE)
    if (fail_count > 0)
      `uvm_error("SCB", "*** TEST FAILED ***")
    else
      `uvm_info("SCB", "*** TEST PASSED ***", UVM_NONE)
  endfunction

endclass
