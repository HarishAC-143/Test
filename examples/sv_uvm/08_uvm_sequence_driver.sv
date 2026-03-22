// =============================================================================
// UVM Sequences, Sequencer, and Driver — Complete Flow
// =============================================================================
//
// Demonstrates:
//   - uvm_sequence_item creation
//   - Simple and layered sequences
//   - start_item / finish_item flow
//   - Driver get_next_item / item_done loop
//   - Response handling
//   - Sequence priority and lock/grab

`include "uvm_macros.svh"
import uvm_pkg::*;

// ---- Transaction ----
class mem_txn extends uvm_sequence_item;
    `uvm_object_utils(mem_txn)

    rand bit [15:0] addr;
    rand bit [31:0] wdata;
    bit      [31:0] rdata;        // filled by driver on reads
    rand bit        write;
    bit              error;       // response status

    constraint aligned_c { addr[1:0] == 0; }
    constraint addr_range_c { addr < 16'h1000; }

    function new(string name = "mem_txn");
        super.new(name);
    endfunction

    virtual function string convert2string();
        if (write)
            return $sformatf("WR [0x%04h] = 0x%08h%s", addr, wdata,
                             error ? " ERR" : "");
        else
            return $sformatf("RD [0x%04h] -> 0x%08h%s", addr, rdata,
                             error ? " ERR" : "");
    endfunction
endclass

// ---- Write sequence ----
class mem_write_seq extends uvm_sequence #(mem_txn);
    `uvm_object_utils(mem_write_seq)

    rand int unsigned num_writes;
    rand bit [15:0]   start_addr;

    constraint c_num  { num_writes inside {[1:16]}; }
    constraint c_addr { start_addr[1:0] == 0; start_addr < 16'h0F00; }

    function new(string name = "mem_write_seq");
        super.new(name);
    endfunction

    virtual task body();
        mem_txn tr;
        `uvm_info(get_type_name(), $sformatf(
            "Writing %0d words starting at 0x%04h", num_writes, start_addr), UVM_LOW)

        for (int i = 0; i < num_writes; i++) begin
            tr = mem_txn::type_id::create($sformatf("wr_%0d", i));
            start_item(tr);
            assert(tr.randomize() with {
                addr  == start_addr + i * 4;
                write == 1;
            }) else `uvm_error(get_type_name(), "Randomization failed")
            finish_item(tr);
            `uvm_info(get_type_name(), tr.convert2string(), UVM_MEDIUM)
        end
    endtask
endclass

// ---- Read sequence ----
class mem_read_seq extends uvm_sequence #(mem_txn);
    `uvm_object_utils(mem_read_seq)

    bit [15:0] addrs[$];

    function new(string name = "mem_read_seq");
        super.new(name);
    endfunction

    virtual task body();
        mem_txn tr;
        `uvm_info(get_type_name(), $sformatf(
            "Reading %0d addresses", addrs.size()), UVM_LOW)

        foreach (addrs[i]) begin
            tr = mem_txn::type_id::create($sformatf("rd_%0d", i));
            start_item(tr);
            assert(tr.randomize() with {
                addr  == addrs[i];
                write == 0;
            }) else `uvm_error(get_type_name(), "Randomization failed")
            finish_item(tr);
            `uvm_info(get_type_name(), tr.convert2string(), UVM_MEDIUM)
        end
    endtask
endclass

// ---- Write-then-read sequence (composed / layered) ----
class mem_wr_rd_seq extends uvm_sequence #(mem_txn);
    `uvm_object_utils(mem_wr_rd_seq)

    rand int unsigned num_pairs;
    constraint c_pairs { num_pairs inside {[4:10]}; }

    function new(string name = "mem_wr_rd_seq");
        super.new(name);
    endfunction

    virtual task body();
        mem_write_seq wr_seq;
        mem_read_seq  rd_seq;

        `uvm_info(get_type_name(), $sformatf(
            "Write-Read sequence: %0d pairs", num_pairs), UVM_LOW)

        // Phase 1: Write
        wr_seq = mem_write_seq::type_id::create("wr_seq");
        wr_seq.num_writes = num_pairs;
        wr_seq.start_addr = 16'h0100;
        wr_seq.start(m_sequencer);

        // Phase 2: Read back same addresses
        rd_seq = mem_read_seq::type_id::create("rd_seq");
        for (int i = 0; i < num_pairs; i++)
            rd_seq.addrs.push_back(16'h0100 + i * 4);
        rd_seq.start(m_sequencer);
    endtask
endclass

// ---- Concurrent sequences demo ----
class mem_concurrent_seq extends uvm_sequence #(mem_txn);
    `uvm_object_utils(mem_concurrent_seq)

    function new(string name = "mem_concurrent_seq");
        super.new(name);
    endfunction

    virtual task body();
        mem_write_seq seq_a, seq_b;

        seq_a = mem_write_seq::type_id::create("seq_a");
        seq_a.start_addr = 16'h0000;
        seq_a.num_writes = 5;

        seq_b = mem_write_seq::type_id::create("seq_b");
        seq_b.start_addr = 16'h0200;
        seq_b.num_writes = 5;

        `uvm_info(get_type_name(), "Starting two sequences concurrently", UVM_LOW)
        fork
            seq_a.start(m_sequencer);
            seq_b.start(m_sequencer);
        join
        `uvm_info(get_type_name(), "Both sequences complete", UVM_LOW)
    endtask
endclass

// ---- Simple memory model driver (no real DUT) ----
class mem_driver extends uvm_driver #(mem_txn);
    `uvm_component_utils(mem_driver)

    bit [31:0] memory[bit [15:0]];

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual task run_phase(uvm_phase phase);
        mem_txn tr;
        forever begin
            seq_item_port.get_next_item(tr);
            #10;  // simulate bus latency
            if (tr.write) begin
                memory[tr.addr] = tr.wdata;
                tr.error = 0;
            end else begin
                if (memory.exists(tr.addr)) begin
                    tr.rdata = memory[tr.addr];
                    tr.error = 0;
                end else begin
                    tr.rdata = 32'hDEAD_DEAD;
                    tr.error = 1;
                end
            end
            seq_item_port.item_done();
        end
    endtask
endclass

// ---- Test ----
class seq_demo_test extends uvm_test;
    `uvm_component_utils(seq_demo_test)

    uvm_sequencer #(mem_txn) sqr;
    mem_driver               drv;

    function new(string name = "seq_demo_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        sqr = uvm_sequencer #(mem_txn)::type_id::create("sqr", this);
        drv = mem_driver::type_id::create("drv", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        drv.seq_item_port.connect(sqr.seq_item_export);
    endfunction

    virtual task run_phase(uvm_phase phase);
        mem_wr_rd_seq     wr_rd;
        mem_concurrent_seq conc;

        phase.raise_objection(this);

        // Test 1: Write then read back
        `uvm_info(get_type_name(), "\n=== Test 1: Write-Read ===", UVM_NONE)
        wr_rd = mem_wr_rd_seq::type_id::create("wr_rd");
        wr_rd.num_pairs = 5;
        wr_rd.start(sqr);

        // Test 2: Concurrent sequences
        `uvm_info(get_type_name(), "\n=== Test 2: Concurrent Sequences ===", UVM_NONE)
        conc = mem_concurrent_seq::type_id::create("conc");
        conc.start(sqr);

        phase.drop_objection(this);
    endtask
endclass

module tb_sequence_driver;
    initial begin
        run_test("seq_demo_test");
    end
endmodule
