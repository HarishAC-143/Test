// FIFO Scoreboard — uses a reference queue to verify FIFO behavior
class fifo_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(fifo_scoreboard)

  uvm_analysis_imp #(fifo_seq_item, fifo_scoreboard) analysis_export;

  // Reference model: a simple queue that mirrors expected FIFO behavior
  bit [7:0] ref_queue[$];
  parameter DEPTH = 16;

  int pass_count = 0;
  int fail_count = 0;
  int write_count = 0;
  int read_count = 0;
  int overflow_count = 0;
  int underflow_count = 0;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    analysis_export = new("analysis_export", this);
  endfunction

  function void write(fifo_seq_item tr);
    if (tr.wr_en) begin
      if (ref_queue.size() < DEPTH) begin
        ref_queue.push_back(tr.wr_data);
        write_count++;
        `uvm_info("SCB", $sformatf("WRITE: 0x%02h (queue size: %0d)",
                  tr.wr_data, ref_queue.size()), UVM_HIGH)
      end else begin
        overflow_count++;
        `uvm_info("SCB", "Write to full FIFO (overflow ignored)", UVM_MEDIUM)
      end
    end

    if (tr.rd_en) begin
      if (ref_queue.size() > 0) begin
        bit [7:0] expected = ref_queue.pop_front();
        read_count++;

        if (tr.rd_data === expected) begin
          pass_count++;
          `uvm_info("SCB", $sformatf("PASS: read 0x%02h (expected 0x%02h)",
                    tr.rd_data, expected), UVM_MEDIUM)
        end else begin
          fail_count++;
          `uvm_error("SCB", $sformatf("FAIL: read 0x%02h (expected 0x%02h)",
                     tr.rd_data, expected))
        end
      end else begin
        underflow_count++;
        `uvm_info("SCB", "Read from empty FIFO (underflow)", UVM_MEDIUM)
      end
    end

    // Verify full/empty flags
    if (tr.full !== (ref_queue.size() == DEPTH))
      `uvm_error("SCB", $sformatf("Full flag mismatch: DUT=%0b expected=%0b",
                 tr.full, (ref_queue.size() == DEPTH)))

    if (tr.empty !== (ref_queue.size() == 0))
      `uvm_error("SCB", $sformatf("Empty flag mismatch: DUT=%0b expected=%0b",
                 tr.empty, (ref_queue.size() == 0)))
  endfunction

  function void report_phase(uvm_phase phase);
    `uvm_info("SCB", "============================================", UVM_LOW)
    `uvm_info("SCB", "       FIFO SCOREBOARD SUMMARY              ", UVM_LOW)
    `uvm_info("SCB", "============================================", UVM_LOW)
    `uvm_info("SCB", $sformatf("  Writes      : %0d", write_count), UVM_LOW)
    `uvm_info("SCB", $sformatf("  Reads       : %0d", read_count), UVM_LOW)
    `uvm_info("SCB", $sformatf("  Passed      : %0d", pass_count), UVM_LOW)
    `uvm_info("SCB", $sformatf("  Failed      : %0d", fail_count), UVM_LOW)
    `uvm_info("SCB", $sformatf("  Overflows   : %0d", overflow_count), UVM_LOW)
    `uvm_info("SCB", $sformatf("  Underflows  : %0d", underflow_count), UVM_LOW)
    `uvm_info("SCB", "============================================", UVM_LOW)
    if (fail_count == 0)
      `uvm_info("SCB", "*** TEST PASSED ***", UVM_NONE)
    else
      `uvm_error("SCB", "*** TEST FAILED ***")
  endfunction

endclass
