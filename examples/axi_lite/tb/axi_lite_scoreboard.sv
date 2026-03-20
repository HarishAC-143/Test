class axi_lite_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(axi_lite_scoreboard)

  uvm_analysis_imp #(axi_lite_transaction, axi_lite_scoreboard) analysis_export;

  // Reference model: register file
  bit [31:0] ref_regs [16];

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
    // Initialize reference registers to zero
    foreach (ref_regs[i]) ref_regs[i] = '0;
  endfunction

  function void write(axi_lite_transaction tx);
    int reg_idx = tx.addr >> 2;

    if (tx.rw) begin
      write_count++;
      // Update reference model with byte-strobes
      for (int i = 0; i < 4; i++) begin
        if (tx.wstrb[i])
          ref_regs[reg_idx][i*8 +: 8] = tx.wdata[i*8 +: 8];
      end

      // Check write response
      if (tx.resp != 2'b00) begin
        fail_count++;
        `uvm_error("SB", $sformatf("WRITE got non-OKAY resp: %s", tx.convert2string()))
      end else begin
        pass_count++;
        `uvm_info("SB", $sformatf("WRITE OK: reg[%0d] = 0x%08h",
                  reg_idx, ref_regs[reg_idx]), UVM_HIGH)
      end
    end else begin
      read_count++;
      bit [31:0] expected = ref_regs[reg_idx];

      if (tx.rdata === expected && tx.resp == 2'b00) begin
        pass_count++;
        `uvm_info("SB", $sformatf("READ PASS: reg[%0d] = 0x%08h",
                  reg_idx, tx.rdata), UVM_HIGH)
      end else begin
        fail_count++;
        `uvm_error("SB", $sformatf(
          "READ FAIL: reg[%0d] exp=0x%08h act=0x%08h resp=%02b",
          reg_idx, expected, tx.rdata, tx.resp))
      end
    end
  endfunction

  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info("SB", $sformatf(
      "\n============================================\n"  +
      "  AXI-Lite Scoreboard Summary\n"                   +
      "  Writes: %0d\n"                                   +
      "  Reads:  %0d\n"                                   +
      "  Pass:   %0d\n"                                   +
      "  Fail:   %0d\n"                                   +
      "============================================",
      write_count, read_count, pass_count, fail_count), UVM_LOW)
    if (fail_count > 0)
      `uvm_error("SB", "TEST FAILED")
    else
      `uvm_info("SB", "TEST PASSED", UVM_LOW)
  endfunction
endclass
