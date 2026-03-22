// UVM Sequence Examples
//
// Demonstrates multiple sequence patterns:
//   - Basic single-item sequence
//   - Parameterized sequence with response handling
//   - Hierarchical (composed) sequence calling sub-sequences
//   - Virtual sequence coordinating multiple sequencers
//   - Sequence with automatic phase objection

`ifndef APB_SEQUENCES_SV
`define APB_SEQUENCES_SV

`include "uvm_macros.svh"
import uvm_pkg::*;

// Forward declaration (transaction defined in 12_uvm_sequence_item.sv)
// class apb_transaction extends uvm_sequence_item;
// class apb_sequencer  extends uvm_sequencer #(apb_transaction);


// ─────────────────────────────────────────────────────────────
//  1. Simple Write Sequence
//     Sends a single write transaction with configurable address
//     and data.
// ─────────────────────────────────────────────────────────────

class apb_write_seq extends uvm_sequence #(apb_transaction);
  `uvm_object_utils(apb_write_seq)

  rand bit [31:0] target_addr;
  rand bit [31:0] target_data;

  function new(string name = "apb_write_seq");
    super.new(name);
  endfunction

  virtual task body();
    apb_transaction txn = apb_transaction::type_id::create("txn");

    start_item(txn);
    if (!txn.randomize() with {
      addr      == target_addr;
      data      == target_data;
      operation == APB_WRITE;
    }) `uvm_fatal("RAND", "Randomization failed in apb_write_seq")
    finish_item(txn);

    `uvm_info(get_type_name(), txn.convert2string(), UVM_MEDIUM)
  endtask
endclass


// ─────────────────────────────────────────────────────────────
//  2. Read Sequence with Response
//     Sends a read request and retrieves the response data.
// ─────────────────────────────────────────────────────────────

class apb_read_seq extends uvm_sequence #(apb_transaction);
  `uvm_object_utils(apb_read_seq)

  rand bit [31:0] target_addr;
  bit [31:0] read_data;
  bit        had_error;

  function new(string name = "apb_read_seq");
    super.new(name);
  endfunction

  virtual task body();
    apb_transaction req, rsp;
    req = apb_transaction::type_id::create("req");

    start_item(req);
    if (!req.randomize() with {
      addr      == target_addr;
      operation == APB_READ;
    }) `uvm_fatal("RAND", "Randomization failed in apb_read_seq")
    finish_item(req);

    get_response(rsp);
    read_data = rsp.read_data;
    had_error = rsp.slv_error;

    `uvm_info(get_type_name(),
      $sformatf("Read from 0x%08h => 0x%08h%s",
                target_addr, read_data,
                had_error ? " [SLAVE ERROR]" : ""),
      UVM_MEDIUM)
  endtask
endclass


// ─────────────────────────────────────────────────────────────
//  3. Write-then-Read-Back Sequence (Composed)
//     Demonstrates hierarchical sequence composition by calling
//     sub-sequences.
// ─────────────────────────────────────────────────────────────

class apb_write_read_seq extends uvm_sequence #(apb_transaction);
  `uvm_object_utils(apb_write_read_seq)

  rand int unsigned num_transactions;
  int               mismatch_count;

  constraint num_c { num_transactions inside {[5:50]}; }

  function new(string name = "apb_write_read_seq");
    super.new(name);
  endfunction

  virtual task body();
    apb_write_seq wr_seq;
    apb_read_seq  rd_seq;

    mismatch_count = 0;

    repeat (num_transactions) begin
      // Write a random value
      wr_seq = apb_write_seq::type_id::create("wr_seq");
      if (!wr_seq.randomize())
        `uvm_fatal("RAND", "Write sequence randomization failed")
      wr_seq.start(m_sequencer, this);  // 'this' = parent sequence

      // Read back from same address
      rd_seq = apb_read_seq::type_id::create("rd_seq");
      rd_seq.target_addr = wr_seq.target_addr;
      rd_seq.start(m_sequencer, this);

      // Verify
      if (rd_seq.read_data !== wr_seq.target_data) begin
        mismatch_count++;
        `uvm_error(get_type_name(),
          $sformatf("Readback mismatch at 0x%08h: wrote 0x%08h, read 0x%08h",
                    wr_seq.target_addr, wr_seq.target_data, rd_seq.read_data))
      end else begin
        `uvm_info(get_type_name(),
          $sformatf("Readback OK at 0x%08h: 0x%08h",
                    wr_seq.target_addr, rd_seq.read_data),
          UVM_HIGH)
      end
    end

    `uvm_info(get_type_name(),
      $sformatf("Write-Read test complete: %0d/%0d passed",
                num_transactions - mismatch_count, num_transactions),
      UVM_LOW)
  endtask
endclass


// ─────────────────────────────────────────────────────────────
//  4. Burst Sequence — Multiple Back-to-Back Writes
//     Demonstrates using the lower-level wait_for_grant /
//     send_request API instead of start_item / finish_item.
// ─────────────────────────────────────────────────────────────

class apb_burst_write_seq extends uvm_sequence #(apb_transaction);
  `uvm_object_utils(apb_burst_write_seq)

  rand bit [31:0]   base_addr;
  rand int unsigned  burst_length;
  rand bit [31:0]   data_pattern[];

  constraint burst_c {
    burst_length inside {[4:16]};
    data_pattern.size() == burst_length;
  }

  constraint base_addr_c {
    base_addr[1:0] == 2'b00;
    base_addr inside {[32'h0000 : 32'hF000]};
  }

  function new(string name = "apb_burst_write_seq");
    super.new(name);
  endfunction

  virtual task body();
    `uvm_info(get_type_name(),
      $sformatf("Starting burst write: base=0x%08h len=%0d",
                base_addr, burst_length),
      UVM_LOW)

    for (int i = 0; i < burst_length; i++) begin
      apb_transaction txn = apb_transaction::type_id::create(
        $sformatf("burst_txn_%0d", i));

      start_item(txn);
      if (!txn.randomize() with {
        addr      == base_addr + (i * 4);
        data      == data_pattern[i];
        operation == APB_WRITE;
        delay     == 0;  // Back-to-back, no idle cycles
      }) `uvm_fatal("RAND", $sformatf("Burst item %0d randomization failed", i))
      finish_item(txn);
    end

    `uvm_info(get_type_name(), "Burst write complete", UVM_LOW)
  endtask
endclass


// ─────────────────────────────────────────────────────────────
//  5. Constrained-Random Stress Sequence
//     Uses automatic phase objection so no explicit
//     raise/drop is needed in the test.
// ─────────────────────────────────────────────────────────────

class apb_stress_seq extends uvm_sequence #(apb_transaction);
  `uvm_object_utils(apb_stress_seq)

  rand int unsigned num_transactions;
  constraint num_c { num_transactions inside {[100:500]}; }

  function new(string name = "apb_stress_seq");
    super.new(name);
    set_automatic_phase_objection(1);
  endfunction

  virtual task body();
    `uvm_info(get_type_name(),
      $sformatf("Starting stress test with %0d transactions",
                num_transactions),
      UVM_LOW)

    repeat (num_transactions) begin
      apb_transaction txn = apb_transaction::type_id::create("txn");
      start_item(txn);
      if (!txn.randomize())
        `uvm_fatal("RAND", "Stress transaction randomization failed")
      finish_item(txn);
    end

    `uvm_info(get_type_name(), "Stress test complete", UVM_LOW)
  endtask
endclass


// ─────────────────────────────────────────────────────────────
//  6. Virtual Sequence — Coordinating Multiple Agents
//     A virtual sequence runs on a virtual sequencer and
//     dispatches sub-sequences to individual agent sequencers.
// ─────────────────────────────────────────────────────────────

// The virtual sequencer holds handles to real sequencers
class apb_virtual_sequencer extends uvm_sequencer;
  `uvm_component_utils(apb_virtual_sequencer)

  apb_sequencer apb_sqr;
  // Additional sequencers for other protocols can be added here
  // axi_sequencer axi_sqr;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
endclass

class apb_virtual_sequence extends uvm_sequence;
  `uvm_object_utils(apb_virtual_sequence)
  `uvm_declare_p_sequencer(apb_virtual_sequencer)

  function new(string name = "apb_virtual_sequence");
    super.new(name);
  endfunction

  virtual task body();
    apb_write_seq wr;
    apb_read_seq  rd;
    apb_burst_write_seq burst;

    // Phase 1: single writes
    repeat (5) begin
      wr = apb_write_seq::type_id::create("wr");
      wr.start(p_sequencer.apb_sqr, this);
    end

    // Phase 2: burst write
    burst = apb_burst_write_seq::type_id::create("burst");
    burst.start(p_sequencer.apb_sqr, this);

    // Phase 3: read-back
    repeat (5) begin
      rd = apb_read_seq::type_id::create("rd");
      if (!rd.randomize()) `uvm_fatal("RAND", "Read randomization failed")
      rd.start(p_sequencer.apb_sqr, this);
    end
  endtask
endclass

`endif
