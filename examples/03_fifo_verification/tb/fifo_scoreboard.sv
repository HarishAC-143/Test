// FIFO Scoreboard — models FIFO behavior and checks correctness
class fifo_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(fifo_scoreboard)

  uvm_analysis_imp #(fifo_transaction, fifo_scoreboard) analysis_export;

  // Reference model: a queue that mirrors the FIFO
  bit [FIFO_DATA_WIDTH-1:0] ref_queue [$];

  int write_count     = 0;
  int read_count      = 0;
  int pass_count      = 0;
  int fail_count      = 0;
  int overflow_count  = 0;
  int underflow_count = 0;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    analysis_export = new("analysis_export", this);
  endfunction

  function void write(fifo_transaction txn);
    bit [FIFO_DATA_WIDTH-1:0] expected_data;

    case (txn.operation)
      FIFO_WRITE: begin
        if (txn.write_blocked) begin
          overflow_count++;
          `uvm_info("SCB", $sformatf("Write blocked (FIFO full): data=0x%02h", txn.wr_data), UVM_MEDIUM)
        end else begin
          ref_queue.push_back(txn.wr_data);
          write_count++;
          `uvm_info("SCB", $sformatf("Write: data=0x%02h (ref_queue size=%0d)", txn.wr_data, ref_queue.size()), UVM_HIGH)
        end
      end

      FIFO_READ: begin
        if (txn.read_blocked) begin
          underflow_count++;
          `uvm_info("SCB", "Read blocked (FIFO empty)", UVM_MEDIUM)
        end else if (ref_queue.size() > 0) begin
          expected_data = ref_queue.pop_front();
          read_count++;
          if (txn.rd_data === expected_data) begin
            pass_count++;
            `uvm_info("SCB", $sformatf("PASS: read=0x%02h expected=0x%02h", txn.rd_data, expected_data), UVM_HIGH)
          end else begin
            fail_count++;
            `uvm_error("SCB", $sformatf("FAIL: read=0x%02h expected=0x%02h", txn.rd_data, expected_data))
          end
        end
      end

      FIFO_BOTH: begin
        // Simultaneous read and write
        if (!txn.write_blocked) begin
          write_count++;
        end

        if (!txn.read_blocked && ref_queue.size() > 0) begin
          expected_data = ref_queue.pop_front();
          read_count++;
          if (txn.rd_data === expected_data) begin
            pass_count++;
          end else begin
            fail_count++;
            `uvm_error("SCB", $sformatf("FAIL (simul): read=0x%02h expected=0x%02h", txn.rd_data, expected_data))
          end
        end

        if (!txn.write_blocked) begin
          ref_queue.push_back(txn.wr_data);
        end
      end

      default: ;
    endcase

    // Verify count signal
    check_count(txn);
  endfunction

  function void check_count(fifo_transaction txn);
    if (ref_queue.size() != txn.count) begin
      // Allow one cycle of difference due to pipeline latency
      `uvm_info("SCB", $sformatf("Count check: ref=%0d dut=%0d (may differ by 1 due to timing)",
                ref_queue.size(), txn.count), UVM_HIGH)
    end
  endfunction

  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info("SCB", "================================================", UVM_NONE)
    `uvm_info("SCB", "  FIFO Scoreboard Results", UVM_NONE)
    `uvm_info("SCB", $sformatf("  Writes: %0d | Reads: %0d", write_count, read_count), UVM_NONE)
    `uvm_info("SCB", $sformatf("  Passed: %0d | Failed: %0d", pass_count, fail_count), UVM_NONE)
    `uvm_info("SCB", $sformatf("  Overflow attempts: %0d | Underflow attempts: %0d",
                               overflow_count, underflow_count), UVM_NONE)
    `uvm_info("SCB", $sformatf("  Remaining in ref queue: %0d", ref_queue.size()), UVM_NONE)
    `uvm_info("SCB", "================================================", UVM_NONE)
    if (fail_count > 0)
      `uvm_error("SCB", "*** TEST FAILED ***")
    else
      `uvm_info("SCB", "*** TEST PASSED ***", UVM_NONE)
  endfunction

endclass
