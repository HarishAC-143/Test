// =============================================================================
// UVM Agent, Environment, and Scoreboard — Full Testbench Structure
// =============================================================================
//
// Demonstrates:
//   - Complete agent with driver, monitor, sequencer
//   - Active vs passive agent configuration
//   - Monitor with analysis port
//   - Scoreboard with uvm_analysis_imp
//   - Multi-port scoreboard using uvm_analysis_imp_decl
//   - Environment connecting agents to scoreboard
//   - uvm_config_db for virtual interface passing
//   - Test with topology printing

`include "uvm_macros.svh"
import uvm_pkg::*;

// ---- Simple interface ----
interface simple_if(input logic clk);
    logic        reset_n;
    logic        valid;
    logic        ready;
    logic        write;
    logic [7:0]  addr;
    logic [31:0] wdata;
    logic [31:0] rdata;

    modport driver  (input clk, reset_n, ready, rdata,
                     output valid, write, addr, wdata);
    modport monitor (input clk, reset_n, valid, ready, write, addr, wdata, rdata);
endinterface

// ---- Transaction ----
class simple_txn extends uvm_sequence_item;
    `uvm_object_utils(simple_txn)

    rand bit [7:0]  addr;
    rand bit [31:0] data;
    rand bit        write;

    function new(string name = "simple_txn");
        super.new(name);
    endfunction

    virtual function void do_copy(uvm_object rhs);
        simple_txn t;
        super.do_copy(rhs);
        $cast(t, rhs);
        addr  = t.addr;
        data  = t.data;
        write = t.write;
    endfunction

    virtual function bit do_compare(uvm_object rhs, uvm_comparer comparer);
        simple_txn t;
        bit eq = super.do_compare(rhs, comparer);
        $cast(t, rhs);
        eq &= (addr == t.addr) && (data == t.data) && (write == t.write);
        return eq;
    endfunction

    virtual function string convert2string();
        return $sformatf("%s [0x%02h] %s 0x%08h",
                         write ? "WR" : "RD", addr,
                         write ? "=" : "->", data);
    endfunction
endclass

// ---- Sequencer (minimal) ----
typedef uvm_sequencer #(simple_txn) simple_sequencer;

// ---- Driver ----
class simple_driver extends uvm_driver #(simple_txn);
    `uvm_component_utils(simple_driver)

    virtual simple_if vif;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db #(virtual simple_if)::get(this, "", "vif", vif))
            `uvm_fatal(get_type_name(), "Virtual interface not found")
    endfunction

    virtual task run_phase(uvm_phase phase);
        simple_txn tr;

        vif.valid <= 0;
        @(posedge vif.reset_n);

        forever begin
            seq_item_port.get_next_item(tr);
            @(posedge vif.clk);
            vif.valid <= 1;
            vif.write <= tr.write;
            vif.addr  <= tr.addr;
            if (tr.write)
                vif.wdata <= tr.data;
            @(posedge vif.clk iff vif.ready);
            if (!tr.write)
                tr.data = vif.rdata;
            vif.valid <= 0;
            seq_item_port.item_done();
            `uvm_info(get_type_name(), {"Driven: ", tr.convert2string()}, UVM_HIGH)
        end
    endtask
endclass

// ---- Monitor ----
class simple_monitor extends uvm_monitor;
    `uvm_component_utils(simple_monitor)

    virtual simple_if vif;
    uvm_analysis_port #(simple_txn) ap;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        ap = new("ap", this);
        if (!uvm_config_db #(virtual simple_if)::get(this, "", "vif", vif))
            `uvm_fatal(get_type_name(), "Virtual interface not found")
    endfunction

    virtual task run_phase(uvm_phase phase);
        simple_txn tr;
        forever begin
            @(posedge vif.clk iff (vif.valid && vif.ready));
            tr = simple_txn::type_id::create("tr");
            tr.addr  = vif.addr;
            tr.write = vif.write;
            tr.data  = vif.write ? vif.wdata : vif.rdata;
            ap.write(tr);
            `uvm_info(get_type_name(), {"Observed: ", tr.convert2string()}, UVM_HIGH)
        end
    endtask
endclass

// ---- Agent ----
class simple_agent extends uvm_agent;
    `uvm_component_utils(simple_agent)

    simple_driver     drv;
    simple_monitor    mon;
    simple_sequencer  sqr;

    uvm_analysis_port #(simple_txn) ap;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        mon = simple_monitor::type_id::create("mon", this);

        if (get_is_active() == UVM_ACTIVE) begin
            drv = simple_driver::type_id::create("drv", this);
            sqr = simple_sequencer::type_id::create("sqr", this);
        end
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        ap = mon.ap;
        if (get_is_active() == UVM_ACTIVE)
            drv.seq_item_port.connect(sqr.seq_item_export);
    endfunction
endclass

// ---- Scoreboard ----
class simple_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(simple_scoreboard)

    uvm_analysis_imp #(simple_txn, simple_scoreboard) analysis_imp;

    bit [31:0] ref_mem[bit [7:0]];
    int writes, reads, matches, mismatches;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        analysis_imp = new("analysis_imp", this);
    endfunction

    virtual function void write(simple_txn tr);
        if (tr.write) begin
            ref_mem[tr.addr] = tr.data;
            writes++;
        end else begin
            reads++;
            if (ref_mem.exists(tr.addr)) begin
                if (tr.data === ref_mem[tr.addr]) begin
                    matches++;
                    `uvm_info(get_type_name(), $sformatf("MATCH [0x%02h]", tr.addr), UVM_MEDIUM)
                end else begin
                    mismatches++;
                    `uvm_error(get_type_name(), $sformatf(
                        "MISMATCH [0x%02h] exp=0x%08h got=0x%08h",
                        tr.addr, ref_mem[tr.addr], tr.data))
                end
            end
        end
    endfunction

    virtual function void report_phase(uvm_phase phase);
        `uvm_info(get_type_name(), $sformatf(
            "\n===== Scoreboard Report =====\n  Writes:     %0d\n  Reads:      %0d\n  Matches:    %0d\n  Mismatches: %0d\n=============================",
            writes, reads, matches, mismatches), UVM_LOW)
    endfunction
endclass

// ---- Environment ----
class simple_env extends uvm_env;
    `uvm_component_utils(simple_env)

    simple_agent      agt;
    simple_scoreboard sb;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        agt = simple_agent::type_id::create("agt", this);
        sb  = simple_scoreboard::type_id::create("sb", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        agt.ap.connect(sb.analysis_imp);
    endfunction
endclass

// ---- Sequences ----
class write_seq extends uvm_sequence #(simple_txn);
    `uvm_object_utils(write_seq)

    function new(string name = "write_seq");
        super.new(name);
    endfunction

    virtual task body();
        simple_txn tr;
        for (int i = 0; i < 10; i++) begin
            tr = simple_txn::type_id::create($sformatf("wr_%0d", i));
            start_item(tr);
            assert(tr.randomize() with { write == 1; addr == i * 4; });
            finish_item(tr);
        end
    endtask
endclass

class read_seq extends uvm_sequence #(simple_txn);
    `uvm_object_utils(read_seq)

    function new(string name = "read_seq");
        super.new(name);
    endfunction

    virtual task body();
        simple_txn tr;
        for (int i = 0; i < 10; i++) begin
            tr = simple_txn::type_id::create($sformatf("rd_%0d", i));
            start_item(tr);
            assert(tr.randomize() with { write == 0; addr == i * 4; });
            finish_item(tr);
        end
    endtask
endclass

// ---- Test ----
class agent_env_test extends uvm_test;
    `uvm_component_utils(agent_env_test)

    simple_env env;

    function new(string name = "agent_env_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = simple_env::type_id::create("env", this);
    endfunction

    virtual function void end_of_elaboration_phase(uvm_phase phase);
        uvm_top.print_topology();
    endfunction

    virtual task run_phase(uvm_phase phase);
        write_seq wseq;
        read_seq  rseq;

        phase.raise_objection(this);

        wseq = write_seq::type_id::create("wseq");
        wseq.start(env.agt.sqr);

        rseq = read_seq::type_id::create("rseq");
        rseq.start(env.agt.sqr);

        #100;
        phase.drop_objection(this);
    endtask

    virtual function void report_phase(uvm_phase phase);
        uvm_report_server svr = uvm_report_server::get_server();
        if (svr.get_severity_count(UVM_ERROR) == 0)
            `uvm_info(get_type_name(), "\n*** TEST PASSED ***", UVM_NONE)
        else
            `uvm_info(get_type_name(), "\n*** TEST FAILED ***", UVM_NONE)
    endfunction
endclass

// ---- Top module (structural) ----
module tb_agent_env;
    logic clk;
    simple_if bus(clk);

    // Simple memory DUT (behavioral model)
    logic [31:0] mem[256];
    always_ff @(posedge clk) begin
        if (bus.valid && bus.ready && bus.write)
            mem[bus.addr] <= bus.wdata;
    end
    assign bus.rdata = mem[bus.addr];
    assign bus.ready = bus.valid;  // always ready (zero wait states)

    // Clock
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Reset
    initial begin
        bus.reset_n = 0;
        #20;
        bus.reset_n = 1;
    end

    // UVM
    initial begin
        uvm_config_db #(virtual simple_if)::set(null, "*.agt.*", "vif", bus);
        run_test("agent_env_test");
    end
endmodule
