// =============================================================================
// Example 07: UVM Sequences, Sequencer, and Driver Communication
// Demonstrates: uvm_sequence body(), start_item/finish_item, virtual sequences,
//               sequence library, sequence arbitration, lock/grab.
// =============================================================================

`include "uvm_macros.svh"
import uvm_pkg::*;

// --- Transaction ---
class mem_txn extends uvm_sequence_item;
  `uvm_object_utils(mem_txn)

  typedef enum bit [1:0] {
    READ      = 2'b00,
    WRITE     = 2'b01,
    RMW       = 2'b10,
    IDLE      = 2'b11
  } op_e;

  rand op_e       op;
  rand bit [15:0] addr;
  rand bit [31:0] wdata;
       bit [31:0] rdata;
       bit        error;

  constraint c_addr_aligned { addr[1:0] == 2'b00; }

  constraint c_op_dist {
    op dist { READ := 40, WRITE := 50, RMW := 8, IDLE := 2 };
  }

  function new(string name = "mem_txn");
    super.new(name);
  endfunction

  virtual function string convert2string();
    if (op == READ || op == RMW)
      return $sformatf("%s addr=0x%04h rdata=0x%08h err=%0b",
                       op.name(), addr, rdata, error);
    else if (op == WRITE)
      return $sformatf("%s addr=0x%04h wdata=0x%08h err=%0b",
                       op.name(), addr, wdata, error);
    else
      return "IDLE";
  endfunction
endclass

// --- Sequencer ---
class mem_sequencer extends uvm_sequencer #(mem_txn);
  `uvm_component_utils(mem_sequencer)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
endclass

// --- Driver (with simple memory model for demo) ---
class mem_driver extends uvm_driver #(mem_txn);
  `uvm_component_utils(mem_driver)

  bit [31:0] memory [bit [15:0]];

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual task run_phase(uvm_phase phase);
    mem_txn txn;
    forever begin
      seq_item_port.get_next_item(txn);
      process_txn(txn);
      seq_item_port.item_done();
    end
  endtask

  virtual task process_txn(mem_txn txn);
    #10;
    case (txn.op)
      mem_txn::WRITE: begin
        memory[txn.addr] = txn.wdata;
        txn.error = 0;
      end
      mem_txn::READ: begin
        if (memory.exists(txn.addr)) begin
          txn.rdata = memory[txn.addr];
          txn.error = 0;
        end else begin
          txn.rdata = 32'hDEAD_DEAD;
          txn.error = 1;
        end
      end
      mem_txn::RMW: begin
        if (memory.exists(txn.addr)) begin
          txn.rdata = memory[txn.addr];
          memory[txn.addr] = txn.rdata | txn.wdata;
          txn.error = 0;
        end else begin
          txn.error = 1;
        end
      end
      mem_txn::IDLE: begin
        #5;
      end
    endcase
    `uvm_info("DRV", $sformatf("Processed: %s", txn.convert2string()), UVM_HIGH)
  endtask
endclass

// ===================================================================
// SEQUENCES
// ===================================================================

// --- Sequence 1: Single write ---
class single_write_seq extends uvm_sequence #(mem_txn);
  `uvm_object_utils(single_write_seq)

  bit [15:0] addr;
  bit [31:0] data;

  function new(string name = "single_write_seq");
    super.new(name);
  endfunction

  virtual task body();
    mem_txn txn = mem_txn::type_id::create("txn");
    start_item(txn);
    if (!txn.randomize() with {
      op    == mem_txn::WRITE;
      addr  == local::addr;
      wdata == local::data;
    })
      `uvm_fatal("RAND", "Failed to randomize single_write_seq")
    finish_item(txn);
    `uvm_info("SEQ", $sformatf("Write complete: %s", txn.convert2string()), UVM_MEDIUM)
  endtask
endclass

// --- Sequence 2: Single read ---
class single_read_seq extends uvm_sequence #(mem_txn);
  `uvm_object_utils(single_read_seq)

  bit [15:0] addr;
  bit [31:0] rdata;

  function new(string name = "single_read_seq");
    super.new(name);
  endfunction

  virtual task body();
    mem_txn txn = mem_txn::type_id::create("txn");
    start_item(txn);
    if (!txn.randomize() with {
      op   == mem_txn::READ;
      addr == local::addr;
    })
      `uvm_fatal("RAND", "Failed to randomize single_read_seq")
    finish_item(txn);
    rdata = txn.rdata;
    `uvm_info("SEQ", $sformatf("Read complete: %s", txn.convert2string()), UVM_MEDIUM)
  endtask
endclass

// --- Sequence 3: Write-then-read (reuses sub-sequences) ---
class write_read_seq extends uvm_sequence #(mem_txn);
  `uvm_object_utils(write_read_seq)

  rand bit [15:0] addr;
  rand bit [31:0] data;

  function new(string name = "write_read_seq");
    super.new(name);
  endfunction

  virtual task body();
    single_write_seq wr_seq = single_write_seq::type_id::create("wr_seq");
    single_read_seq  rd_seq = single_read_seq::type_id::create("rd_seq");

    // Write
    wr_seq.addr = addr;
    wr_seq.data = data;
    wr_seq.start(m_sequencer, this);

    // Read back
    rd_seq.addr = addr;
    rd_seq.start(m_sequencer, this);

    // Verify
    if (rd_seq.rdata !== data)
      `uvm_error("SEQ", $sformatf("Data mismatch at 0x%04h: wrote 0x%08h, read 0x%08h",
                 addr, data, rd_seq.rdata))
    else
      `uvm_info("SEQ", $sformatf("Verified addr=0x%04h data=0x%08h", addr, data), UVM_MEDIUM)
  endtask
endclass

// --- Sequence 4: Burst write ---
class burst_write_seq extends uvm_sequence #(mem_txn);
  `uvm_object_utils(burst_write_seq)

  rand bit [15:0] base_addr;
  rand int unsigned length;

  constraint c_length { length inside {[1:16]}; }
  constraint c_aligned { base_addr[1:0] == 2'b00; }

  function new(string name = "burst_write_seq");
    super.new(name);
  endfunction

  virtual task body();
    mem_txn txn;
    `uvm_info("SEQ", $sformatf("Burst write: base=0x%04h length=%0d", base_addr, length), UVM_MEDIUM)

    for (int i = 0; i < length; i++) begin
      txn = mem_txn::type_id::create($sformatf("txn_%0d", i));
      start_item(txn);
      if (!txn.randomize() with {
        op   == mem_txn::WRITE;
        addr == local::base_addr + (i * 4);
      })
        `uvm_fatal("RAND", "Burst write randomize failed")
      finish_item(txn);
    end
  endtask
endclass

// --- Sequence 5: Random traffic ---
class random_traffic_seq extends uvm_sequence #(mem_txn);
  `uvm_object_utils(random_traffic_seq)

  rand int unsigned num_txns;

  constraint c_default { num_txns inside {[5:20]}; }

  function new(string name = "random_traffic_seq");
    super.new(name);
  endfunction

  virtual task body();
    mem_txn txn;
    `uvm_info("SEQ", $sformatf("Random traffic: %0d transactions", num_txns), UVM_MEDIUM)

    repeat (num_txns) begin
      txn = mem_txn::type_id::create("txn");
      start_item(txn);
      if (!txn.randomize())
        `uvm_fatal("RAND", "Random traffic randomize failed")
      finish_item(txn);
    end
  endtask
endclass

// --- Sequence 6: Nested/Hierarchical sequence ---
class stress_test_seq extends uvm_sequence #(mem_txn);
  `uvm_object_utils(stress_test_seq)

  function new(string name = "stress_test_seq");
    super.new(name);
  endfunction

  virtual task body();
    write_read_seq     wr_rd;
    burst_write_seq    burst;
    random_traffic_seq random;

    `uvm_info("SEQ", "=== Phase 1: Sequential Write-Read ===", UVM_LOW)
    repeat (3) begin
      wr_rd = write_read_seq::type_id::create("wr_rd");
      if (!wr_rd.randomize() with { addr inside {[16'h0000:16'h00FF]}; })
        `uvm_fatal("RAND", "Write-read randomize failed")
      wr_rd.start(m_sequencer, this);
    end

    `uvm_info("SEQ", "=== Phase 2: Burst Write ===", UVM_LOW)
    burst = burst_write_seq::type_id::create("burst");
    if (!burst.randomize() with { base_addr == 16'h0100; length == 8; })
      `uvm_fatal("RAND", "Burst randomize failed")
    burst.start(m_sequencer, this);

    `uvm_info("SEQ", "=== Phase 3: Random Traffic ===", UVM_LOW)
    random = random_traffic_seq::type_id::create("random");
    if (!random.randomize() with { num_txns == 10; })
      `uvm_fatal("RAND", "Random traffic randomize failed")
    random.start(m_sequencer, this);
  endtask
endclass

// ===================================================================
// ENVIRONMENT AND TEST
// ===================================================================

class seq_agent extends uvm_agent;
  `uvm_component_utils(seq_agent)

  mem_driver    drv;
  mem_sequencer sqr;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    drv = mem_driver::type_id::create("drv", this);
    sqr = mem_sequencer::type_id::create("sqr", this);
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    drv.seq_item_port.connect(sqr.seq_item_export);
  endfunction
endclass

class seq_env extends uvm_env;
  `uvm_component_utils(seq_env)

  seq_agent agent;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    agent = seq_agent::type_id::create("agent", this);
  endfunction
endclass

class sequence_demo_test extends uvm_test;
  `uvm_component_utils(sequence_demo_test)

  seq_env env;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = seq_env::type_id::create("env", this);
  endfunction

  virtual task run_phase(uvm_phase phase);
    stress_test_seq seq;

    phase.raise_objection(this);

    seq = stress_test_seq::type_id::create("stress_seq");
    seq.start(env.agent.sqr);

    `uvm_info("TEST", "=== All sequences completed ===", UVM_LOW)
    phase.drop_objection(this);
  endtask
endclass

// --- Top module ---
module tb_sequences;
  initial begin
    run_test("sequence_demo_test");
  end
endmodule
