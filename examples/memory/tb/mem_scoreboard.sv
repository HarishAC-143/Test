class mem_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(mem_scoreboard)

  uvm_analysis_imp #(mem_transaction, mem_scoreboard) analysis_export;

  // Reference model: associative array mirroring the memory
  bit [31:0] ref_mem [bit [7:0]];

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

  function void write(mem_transaction tx);
    if (tx.we) begin
      check_write(tx);
    end else if (tx.re) begin
      check_read(tx);
    end
  endfunction

  function void check_write(mem_transaction tx);
    bit [31:0] current_val;

    write_count++;

    if (ref_mem.exists(tx.addr))
      current_val = ref_mem[tx.addr];
    else
      current_val = '0;

    // Apply byte enables
    for (int i = 0; i < 4; i++) begin
      if (tx.be[i])
        current_val[i*8 +: 8] = tx.wdata[i*8 +: 8];
    end

    ref_mem[tx.addr] = current_val;

    `uvm_info("SB", $sformatf("WRITE: mem[0x%02h] = 0x%08h (be=0x%01h)",
              tx.addr, current_val, tx.be), UVM_HIGH)
  endfunction

  function void check_read(mem_transaction tx);
    bit [31:0] expected;

    read_count++;

    if (ref_mem.exists(tx.addr))
      expected = ref_mem[tx.addr];
    else
      expected = '0;

    if (tx.rdata === expected) begin
      pass_count++;
      `uvm_info("SB", $sformatf("READ PASS: mem[0x%02h] = 0x%08h",
                tx.addr, tx.rdata), UVM_HIGH)
    end else begin
      fail_count++;
      `uvm_error("SB", $sformatf(
        "READ FAIL: mem[0x%02h] exp=0x%08h act=0x%08h",
        tx.addr, expected, tx.rdata))
    end
  endfunction

  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info("SB", $sformatf(
      "\n============================================\n"  +
      "  Memory Scoreboard Summary\n"                     +
      "  Writes:     %0d\n"                               +
      "  Reads:      %0d\n"                               +
      "  Read Pass:  %0d\n"                               +
      "  Read Fail:  %0d\n"                               +
      "============================================",
      write_count, read_count, pass_count, fail_count), UVM_LOW)
    if (fail_count > 0)
      `uvm_error("SB", "TEST FAILED")
    else
      `uvm_info("SB", "TEST PASSED", UVM_LOW)
  endfunction
endclass
