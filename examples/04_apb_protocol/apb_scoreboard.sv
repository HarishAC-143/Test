class apb_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(apb_scoreboard)

  uvm_analysis_imp #(apb_seq_item, apb_scoreboard) analysis_export;

  // Reference memory model
  bit [31:0] ref_mem [bit [7:0]];
  int pass_count, fail_count, total_writes, total_reads;

  function new(string name = "apb_scoreboard", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    analysis_export = new("analysis_export", this);
  endfunction

  function void write(apb_seq_item tx);
    if (tx.slverr) begin
      `uvm_info("SB", $sformatf("Slave error response for addr=0x%02h — skipping check", tx.addr), UVM_MEDIUM)
      return;
    end

    if (tx.direction == APB_WRITE) begin
      check_write(tx);
    end else begin
      check_read(tx);
    end
  endfunction

  function void check_write(apb_seq_item tx);
    bit [7:0] word_addr = {tx.addr[7:2], 2'b00};
    bit [31:0] current_val;

    total_writes++;

    if (!ref_mem.exists(word_addr))
      current_val = 32'h0;
    else
      current_val = ref_mem[word_addr];

    // Apply byte strobes
    for (int i = 0; i < 4; i++) begin
      if (tx.strb[i])
        current_val[i*8 +: 8] = tx.wdata[i*8 +: 8];
    end

    ref_mem[word_addr] = current_val;
    `uvm_info("SB", $sformatf("WRITE: addr=0x%02h data=0x%08h strb=0x%01h",
              word_addr, current_val, tx.strb), UVM_HIGH)
  endfunction

  function void check_read(apb_seq_item tx);
    bit [7:0] word_addr = {tx.addr[7:2], 2'b00};
    bit [31:0] expected;

    total_reads++;

    if (!ref_mem.exists(word_addr))
      expected = 32'h0;
    else
      expected = ref_mem[word_addr];

    if (tx.rdata !== expected) begin
      fail_count++;
      `uvm_error("SB", $sformatf("READ MISMATCH: addr=0x%02h expected=0x%08h got=0x%08h",
                 word_addr, expected, tx.rdata))
    end else begin
      pass_count++;
      `uvm_info("SB", $sformatf("READ MATCH: addr=0x%02h data=0x%08h", word_addr, tx.rdata), UVM_HIGH)
    end
  endfunction

  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info("SB", $sformatf(
      "\n============================================\n" +
      "  APB Scoreboard Summary\n" +
      "  Writes: %0d | Reads: %0d\n" +
      "  Read Checks — Pass: %0d | Fail: %0d\n" +
      "============================================",
      total_writes, total_reads, pass_count, fail_count), UVM_LOW)

    if (fail_count > 0)
      `uvm_error("SB", "*** TEST FAILED ***")
    else
      `uvm_info("SB", "*** ALL CHECKS PASSED ***", UVM_LOW)
  endfunction
endclass
