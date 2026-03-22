// =============================================================================
// Example 07: UVM Sequences, Sequencer, and Driver
// Covers: uvm_sequence body/start_item/finish_item, sequence nesting,
//         uvm_sequencer arbitration, uvm_driver get_next_item/item_done,
//         response handling, and sequence coordination
// =============================================================================

`include "uvm_macros.svh"
import uvm_pkg::*;


// ─── Transaction ───
class mem_txn extends uvm_sequence_item;
  `uvm_object_utils(mem_txn)

  rand bit [15:0] addr;
  rand bit [31:0] wdata;
       bit [31:0] rdata;
  rand bit        write;
  rand int        delay;
  bit  [1:0]      resp;

  constraint c_addr_align { addr[1:0] == 2'b00; }
  constraint c_delay      { delay inside {[0:5]}; }

  function new(string name = "mem_txn");
    super.new(name);
  endfunction

  virtual function string convert2string();
    if (write)
      return $sformatf("WR addr=0x%04h wdata=0x%08h delay=%0d resp=%0d",
                       addr, wdata, delay, resp);
    else
      return $sformatf("RD addr=0x%04h rdata=0x%08h delay=%0d resp=%0d",
                       addr, rdata, delay, resp);
  endfunction

  virtual function void do_copy(uvm_object rhs);
    mem_txn t;
    super.do_copy(rhs);
    $cast(t, rhs);
    addr  = t.addr;
    wdata = t.wdata;
    rdata = t.rdata;
    write = t.write;
    delay = t.delay;
    resp  = t.resp;
  endfunction
endclass


// ─── Sequences ───

// Single write
class mem_write_seq extends uvm_sequence #(mem_txn);
  `uvm_object_utils(mem_write_seq)

  bit [15:0] target_addr;
  bit [31:0] target_data;

  function new(string name = "mem_write_seq");
    super.new(name);
  endfunction

  virtual task body();
    mem_txn txn = mem_txn::type_id::create("txn");
    start_item(txn);
    if (!txn.randomize() with {
      addr  == local::target_addr;
      wdata == local::target_data;
      write == 1;
    })
      `uvm_fatal("SEQ", "Randomization failed")
    finish_item(txn);
    `uvm_info("WR_SEQ", txn.convert2string(), UVM_MEDIUM)
  endtask
endclass

// Single read
class mem_read_seq extends uvm_sequence #(mem_txn);
  `uvm_object_utils(mem_read_seq)

  bit [15:0] target_addr;
  bit [31:0] read_data;

  function new(string name = "mem_read_seq");
    super.new(name);
  endfunction

  virtual task body();
    mem_txn txn = mem_txn::type_id::create("txn");
    start_item(txn);
    if (!txn.randomize() with {
      addr  == local::target_addr;
      write == 0;
    })
      `uvm_fatal("SEQ", "Randomization failed")
    finish_item(txn);
    read_data = txn.rdata;
    `uvm_info("RD_SEQ", txn.convert2string(), UVM_MEDIUM)
  endtask
endclass

// Bulk write sequence
class mem_bulk_write_seq extends uvm_sequence #(mem_txn);
  `uvm_object_utils(mem_bulk_write_seq)

  rand bit [15:0]      start_addr;
  rand int unsigned    count;
  rand bit [31:0]      pattern;

  constraint c_count { count inside {[1:16]}; }

  function new(string name = "mem_bulk_write_seq");
    super.new(name);
  endfunction

  virtual task body();
    mem_txn txn;
    `uvm_info("BULK_WR", $sformatf("Writing %0d words starting at 0x%04h",
              count, start_addr), UVM_LOW)

    for (int i = 0; i < count; i++) begin
      txn = mem_txn::type_id::create($sformatf("txn_%0d", i));
      start_item(txn);
      if (!txn.randomize() with {
        addr  == local::start_addr + (i * 4);
        wdata == local::pattern + i;
        write == 1;
      })
        `uvm_fatal("SEQ", "Randomization failed")
      finish_item(txn);
    end
  endtask
endclass

// Write-then-read-back sequence (nests other sequences)
class mem_write_read_seq extends uvm_sequence #(mem_txn);
  `uvm_object_utils(mem_write_read_seq)

  rand bit [15:0] start_addr;
  rand int unsigned count;

  constraint c_count { count inside {[1:8]}; }

  function new(string name = "mem_write_read_seq");
    super.new(name);
  endfunction

  virtual task body();
    mem_write_seq wr_seq;
    mem_read_seq  rd_seq;
    bit [31:0]    expected_data[$];

    `uvm_info("WR_RD", $sformatf("Write-read-back %0d locations from 0x%04h",
              count, start_addr), UVM_LOW)

    // Phase 1: Write random data
    for (int i = 0; i < count; i++) begin
      bit [31:0] d = $urandom();
      expected_data.push_back(d);

      wr_seq = mem_write_seq::type_id::create("wr_seq");
      wr_seq.target_addr = start_addr + (i * 4);
      wr_seq.target_data = d;
      wr_seq.start(m_sequencer, this);
    end

    // Phase 2: Read back and verify
    for (int i = 0; i < count; i++) begin
      rd_seq = mem_read_seq::type_id::create("rd_seq");
      rd_seq.target_addr = start_addr + (i * 4);
      rd_seq.start(m_sequencer, this);

      if (rd_seq.read_data !== expected_data[i])
        `uvm_error("WR_RD", $sformatf(
          "MISMATCH addr=0x%04h exp=0x%08h got=0x%08h",
          start_addr + (i * 4), expected_data[i], rd_seq.read_data))
      else
        `uvm_info("WR_RD", $sformatf(
          "MATCH addr=0x%04h data=0x%08h",
          start_addr + (i * 4), rd_seq.read_data), UVM_MEDIUM)
    end
  endtask
endclass

// Random traffic
class mem_random_seq extends uvm_sequence #(mem_txn);
  `uvm_object_utils(mem_random_seq)

  rand int unsigned num_txns;
  constraint c_num { num_txns inside {[5:20]}; }

  function new(string name = "mem_random_seq");
    super.new(name);
  endfunction

  virtual task body();
    mem_txn txn;
    `uvm_info("RAND_SEQ", $sformatf("Generating %0d random transactions", num_txns), UVM_LOW)

    repeat (num_txns) begin
      txn = mem_txn::type_id::create("txn");
      start_item(txn);
      if (!txn.randomize())
        `uvm_fatal("SEQ", "Randomization failed")
      finish_item(txn);
    end
  endtask
endclass


// ─── Sequencer ───
typedef uvm_sequencer #(mem_txn) mem_sequencer;


// ─── Driver with Memory Model ───
class mem_driver extends uvm_driver #(mem_txn);
  `uvm_component_utils(mem_driver)

  bit [31:0] memory [bit [15:0]];
  int        txn_count;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual task run_phase(uvm_phase phase);
    mem_txn txn;
    txn_count = 0;

    forever begin
      seq_item_port.get_next_item(txn);
      drive(txn);
      txn_count++;
      seq_item_port.item_done();
    end
  endtask

  virtual task drive(mem_txn txn);
    #(txn.delay * 10);

    if (txn.write) begin
      memory[txn.addr] = txn.wdata;
      txn.resp = 2'b00;
      `uvm_info("DRV", $sformatf("[%0d] %s", txn_count, txn.convert2string()), UVM_HIGH)
    end else begin
      if (memory.exists(txn.addr)) begin
        txn.rdata = memory[txn.addr];
        txn.resp  = 2'b00;
      end else begin
        txn.rdata = 32'hDEAD_DEAD;
        txn.resp  = 2'b10;
      end
      `uvm_info("DRV", $sformatf("[%0d] %s", txn_count, txn.convert2string()), UVM_HIGH)
    end
  endtask

  virtual function void report_phase(uvm_phase phase);
    `uvm_info("DRV", $sformatf("Drove %0d transactions, memory has %0d entries",
              txn_count, memory.size()), UVM_LOW)
  endfunction
endclass


// ─── Agent / Env / Test ───
class mem_agent extends uvm_agent;
  `uvm_component_utils(mem_agent)

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


class mem_env extends uvm_env;
  `uvm_component_utils(mem_env)
  mem_agent agent;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    agent = mem_agent::type_id::create("agent", this);
  endfunction
endclass


class seq_demo_test extends uvm_test;
  `uvm_component_utils(seq_demo_test)
  mem_env env;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = mem_env::type_id::create("env", this);
  endfunction

  virtual task run_phase(uvm_phase phase);
    mem_write_read_seq wr_rd_seq;
    mem_random_seq     rand_seq;

    phase.raise_objection(this);

    `uvm_info("TEST", "=== Running write-read-back sequence ===", UVM_LOW)
    wr_rd_seq = mem_write_read_seq::type_id::create("wr_rd_seq");
    wr_rd_seq.start_addr = 16'h0100;
    wr_rd_seq.count      = 4;
    wr_rd_seq.start(env.agent.sqr);

    `uvm_info("TEST", "\n=== Running random traffic sequence ===", UVM_LOW)
    rand_seq = mem_random_seq::type_id::create("rand_seq");
    rand_seq.num_txns = 10;
    rand_seq.start(env.agent.sqr);

    #100;
    phase.drop_objection(this);
  endtask
endclass


module tb_sequence_driver;
  initial begin
    run_test("seq_demo_test");
  end
endmodule
