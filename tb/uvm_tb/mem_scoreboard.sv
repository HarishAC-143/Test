//----------------------------------------------------------------------
// Memory Scoreboard
//
// Maintains a reference model (associative array) of expected memory
// contents.  Compares actual read data against predicted values and
// reports mismatches.
//----------------------------------------------------------------------
class mem_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(mem_scoreboard)

  uvm_analysis_imp_decl(_write)
  uvm_analysis_imp_decl(_read)

  uvm_analysis_imp_write #(mem_seq_item, mem_scoreboard) write_imp;
  uvm_analysis_imp_read  #(mem_seq_item, mem_scoreboard) read_imp;

  // Reference model
  bit [7:0] ref_mem [bit[3:0]];

  // Counters
  int unsigned write_count;
  int unsigned read_count;
  int unsigned match_count;
  int unsigned mismatch_count;

  function new(string name = "mem_scoreboard", uvm_component parent = null);
    super.new(name, parent);
    write_count    = 0;
    read_count     = 0;
    match_count    = 0;
    mismatch_count = 0;
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    write_imp = new("write_imp", this);
    read_imp  = new("read_imp",  this);
  endfunction

  // Called when a write transaction is observed
  function void write_write(mem_seq_item txn);
    ref_mem[txn.addr] = txn.wdata;
    write_count++;
    `uvm_info(get_type_name(),
      $sformatf("WRITE: addr=0x%0h data=0x%0h (ref updated)", txn.addr, txn.wdata),
      UVM_HIGH)
  endfunction

  // Called when a read transaction is observed
  function void write_read(mem_seq_item txn);
    bit [7:0] expected;

    read_count++;

    if (!txn.valid) begin
      `uvm_info(get_type_name(),
        $sformatf("READ: addr=0x%0h - valid not asserted, skipping check", txn.addr),
        UVM_MEDIUM)
      return;
    end

    if (ref_mem.exists(txn.addr)) begin
      expected = ref_mem[txn.addr];
      if (txn.rdata === expected) begin
        match_count++;
        `uvm_info(get_type_name(),
          $sformatf("READ MATCH: addr=0x%0h expected=0x%0h actual=0x%0h",
                    txn.addr, expected, txn.rdata),
          UVM_MEDIUM)
      end else begin
        mismatch_count++;
        `uvm_error(get_type_name(),
          $sformatf("READ MISMATCH: addr=0x%0h expected=0x%0h actual=0x%0h",
                    txn.addr, expected, txn.rdata))
      end
    end else begin
      `uvm_info(get_type_name(),
        $sformatf("READ: addr=0x%0h data=0x%0h (no prior write, skipping check)",
                  txn.addr, txn.rdata),
        UVM_MEDIUM)
    end
  endfunction

  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info(get_type_name(), "========== SCOREBOARD SUMMARY ==========", UVM_LOW)
    `uvm_info(get_type_name(), $sformatf("  Total writes    : %0d", write_count), UVM_LOW)
    `uvm_info(get_type_name(), $sformatf("  Total reads     : %0d", read_count), UVM_LOW)
    `uvm_info(get_type_name(), $sformatf("  Matches         : %0d", match_count), UVM_LOW)
    `uvm_info(get_type_name(), $sformatf("  Mismatches      : %0d", mismatch_count), UVM_LOW)
    `uvm_info(get_type_name(), "========================================", UVM_LOW)
    if (mismatch_count > 0)
      `uvm_error(get_type_name(), $sformatf("TEST FAILED with %0d mismatches", mismatch_count))
    else
      `uvm_info(get_type_name(), "TEST PASSED - All reads matched expected values", UVM_LOW)
  endfunction
endclass
