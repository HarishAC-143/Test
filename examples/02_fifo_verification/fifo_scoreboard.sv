class fifo_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(fifo_scoreboard)

  uvm_analysis_imp #(fifo_transaction, fifo_scoreboard) analysis_export;

  // Reference model: queue acting as golden FIFO
  bit [7:0] ref_fifo[$];
  int pass_count, fail_count;
  int max_depth = 16;

  function new(string name = "fifo_scoreboard", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    analysis_export = new("analysis_export", this);
  endfunction

  function void write(fifo_transaction tx);
    if (tx.op == FIFO_WRITE) begin
      check_write(tx);
    end else begin
      check_read(tx);
    end
  endfunction

  function void check_write(fifo_transaction tx);
    if (ref_fifo.size() < max_depth) begin
      ref_fifo.push_back(tx.data);
      `uvm_info("SB", $sformatf("WRITE 0x%02h accepted (depth=%0d)", tx.data, ref_fifo.size()), UVM_HIGH)
      pass_count++;
    end else begin
      if (!tx.overflow)
        `uvm_error("SB", "Expected overflow flag but not asserted")
      else begin
        `uvm_info("SB", "Overflow correctly detected", UVM_MEDIUM)
        pass_count++;
      end
    end
  endfunction

  function void check_read(fifo_transaction tx);
    if (ref_fifo.size() > 0) begin
      bit [7:0] expected = ref_fifo.pop_front();
      if (tx.rd_data !== expected) begin
        fail_count++;
        `uvm_error("SB", $sformatf("READ MISMATCH: expected=0x%02h got=0x%02h", expected, tx.rd_data))
      end else begin
        pass_count++;
        `uvm_info("SB", $sformatf("READ MATCH: 0x%02h (depth=%0d)", tx.rd_data, ref_fifo.size()), UVM_HIGH)
      end
    end else begin
      if (!tx.underflow)
        `uvm_error("SB", "Expected underflow flag but not asserted")
      else begin
        `uvm_info("SB", "Underflow correctly detected", UVM_MEDIUM)
        pass_count++;
      end
    end
  endfunction

  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info("SB", $sformatf(
      "\n============================================\n" +
      "  FIFO Scoreboard Summary\n" +
      "  Total: %0d | Pass: %0d | Fail: %0d\n" +
      "  Remaining in ref FIFO: %0d\n" +
      "============================================",
      pass_count + fail_count, pass_count, fail_count, ref_fifo.size()), UVM_LOW)

    if (fail_count > 0)
      `uvm_error("SB", "*** TEST FAILED ***")
    else
      `uvm_info("SB", "*** ALL CHECKS PASSED ***", UVM_LOW)
  endfunction
endclass
