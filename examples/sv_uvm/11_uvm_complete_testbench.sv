// =============================================================================
// Complete UVM Testbench — APB Memory Slave
// =============================================================================
//
// A self-contained, fully functional UVM testbench for a simple APB memory.
// Includes: DUT, interface, transaction, sequences, driver, monitor,
//           agent, scoreboard, environment, and tests.
//
// Run with: +UVM_TESTNAME=apb_wr_rd_test

`include "uvm_macros.svh"
import uvm_pkg::*;

// =============================================================================
//  DUT: Simple APB Memory Slave
// =============================================================================
module apb_memory #(
    parameter ADDR_WIDTH = 8,
    parameter DATA_WIDTH = 32
)(
    input  logic                    pclk,
    input  logic                    preset_n,
    input  logic                    psel,
    input  logic                    penable,
    input  logic                    pwrite,
    input  logic [ADDR_WIDTH-1:0]   paddr,
    input  logic [DATA_WIDTH-1:0]   pwdata,
    output logic [DATA_WIDTH-1:0]   prdata,
    output logic                    pready,
    output logic                    pslverr
);

    logic [DATA_WIDTH-1:0] mem [0:(1<<ADDR_WIDTH)-1];

    typedef enum logic [1:0] {IDLE, SETUP, ACCESS} state_e;
    state_e state, next_state;

    always_ff @(posedge pclk or negedge preset_n)
        if (!preset_n) state <= IDLE;
        else           state <= next_state;

    always_comb begin
        next_state = state;
        case (state)
            IDLE:    if (psel && !penable)  next_state = SETUP;
            SETUP:   if (psel && penable)   next_state = ACCESS;
            ACCESS:                         next_state = IDLE;
            default:                        next_state = IDLE;
        endcase
    end

    assign pready  = (state == ACCESS);
    assign pslverr = 1'b0;

    always_ff @(posedge pclk)
        if (state == ACCESS && pwrite)
            mem[paddr] <= pwdata;

    assign prdata = (state == ACCESS && !pwrite) ? mem[paddr] : '0;
endmodule

// =============================================================================
//  Interface
// =============================================================================
interface apb_if(input logic pclk);
    logic        preset_n;
    logic        psel;
    logic        penable;
    logic        pwrite;
    logic [7:0]  paddr;
    logic [31:0] pwdata;
    logic [31:0] prdata;
    logic        pready;
    logic        pslverr;

    clocking drv_cb @(posedge pclk);
        output psel, penable, pwrite, paddr, pwdata;
        input  prdata, pready, pslverr;
    endclocking

    clocking mon_cb @(posedge pclk);
        input psel, penable, pwrite, paddr, pwdata, prdata, pready, pslverr;
    endclocking
endinterface

// =============================================================================
//  Transaction
// =============================================================================
class apb_txn extends uvm_sequence_item;
    `uvm_object_utils(apb_txn)

    rand bit [7:0]  addr;
    rand bit [31:0] data;
    rand bit        write;

    constraint aligned_c { addr[1:0] == 0; }

    function new(string name = "apb_txn");
        super.new(name);
    endfunction

    virtual function void do_copy(uvm_object rhs);
        apb_txn t;
        super.do_copy(rhs);
        $cast(t, rhs);
        addr = t.addr; data = t.data; write = t.write;
    endfunction

    virtual function bit do_compare(uvm_object rhs, uvm_comparer comparer);
        apb_txn t;
        bit eq = super.do_compare(rhs, comparer);
        $cast(t, rhs);
        return eq && (addr == t.addr) && (data == t.data) && (write == t.write);
    endfunction

    virtual function string convert2string();
        return $sformatf("%s [0x%02h] %s 0x%08h",
                         write ? "WR" : "RD", addr,
                         write ? "<=" : "=>", data);
    endfunction
endclass

// =============================================================================
//  Sequences
// =============================================================================

// Single-operation sequence
class apb_single_seq extends uvm_sequence #(apb_txn);
    `uvm_object_utils(apb_single_seq)

    rand bit [7:0]  target_addr;
    rand bit [31:0] target_data;
    rand bit        is_write;

    function new(string name = "apb_single_seq");
        super.new(name);
    endfunction

    virtual task body();
        apb_txn tr = apb_txn::type_id::create("tr");
        start_item(tr);
        assert(tr.randomize() with {
            addr  == target_addr;
            data  == target_data;
            write == is_write;
        });
        finish_item(tr);
    endtask
endclass

// Write-then-read-back sequence
class apb_wr_rd_seq extends uvm_sequence #(apb_txn);
    `uvm_object_utils(apb_wr_rd_seq)

    rand int num_pairs;
    constraint c { num_pairs inside {[5:20]}; }

    function new(string name = "apb_wr_rd_seq");
        super.new(name);
    endfunction

    virtual task body();
        apb_txn tr;
        bit [7:0]  addrs[$];
        bit [31:0] datas[$];

        `uvm_info(get_type_name(), $sformatf(
            "Running %0d write-read pairs", num_pairs), UVM_LOW)

        // Write phase
        for (int i = 0; i < num_pairs; i++) begin
            tr = apb_txn::type_id::create($sformatf("wr_%0d", i));
            start_item(tr);
            assert(tr.randomize() with { write == 1; });
            finish_item(tr);
            addrs.push_back(tr.addr);
            datas.push_back(tr.data);
            `uvm_info(get_type_name(), {"  ", tr.convert2string()}, UVM_MEDIUM)
        end

        // Read-back phase
        for (int i = 0; i < num_pairs; i++) begin
            tr = apb_txn::type_id::create($sformatf("rd_%0d", i));
            start_item(tr);
            assert(tr.randomize() with {
                addr  == addrs[i];
                write == 0;
            });
            finish_item(tr);
            `uvm_info(get_type_name(), {"  ", tr.convert2string()}, UVM_MEDIUM)
        end
    endtask
endclass

// Random traffic sequence
class apb_random_seq extends uvm_sequence #(apb_txn);
    `uvm_object_utils(apb_random_seq)

    rand int count;
    constraint c { count inside {[20:50]}; }

    function new(string name = "apb_random_seq");
        super.new(name);
    endfunction

    virtual task body();
        apb_txn tr;
        repeat (count) begin
            tr = apb_txn::type_id::create("tr");
            start_item(tr);
            assert(tr.randomize());
            finish_item(tr);
        end
    endtask
endclass

// =============================================================================
//  Driver
// =============================================================================
class apb_driver extends uvm_driver #(apb_txn);
    `uvm_component_utils(apb_driver)

    virtual apb_if vif;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db #(virtual apb_if)::get(this, "", "vif", vif))
            `uvm_fatal(get_type_name(), "No virtual interface")
    endfunction

    virtual task run_phase(uvm_phase phase);
        apb_txn tr;
        vif.drv_cb.psel    <= 0;
        vif.drv_cb.penable <= 0;
        @(posedge vif.preset_n);
        @(vif.drv_cb);

        forever begin
            seq_item_port.get_next_item(tr);
            drive(tr);
            seq_item_port.item_done();
        end
    endtask

    task drive(apb_txn tr);
        // Setup phase
        @(vif.drv_cb);
        vif.drv_cb.psel   <= 1;
        vif.drv_cb.pwrite <= tr.write;
        vif.drv_cb.paddr  <= tr.addr;
        if (tr.write) vif.drv_cb.pwdata <= tr.data;

        // Access phase
        @(vif.drv_cb);
        vif.drv_cb.penable <= 1;

        // Wait for ready
        do @(vif.drv_cb); while (!vif.drv_cb.pready);

        if (!tr.write) tr.data = vif.drv_cb.prdata;

        // Idle
        vif.drv_cb.psel    <= 0;
        vif.drv_cb.penable <= 0;
    endtask
endclass

// =============================================================================
//  Monitor
// =============================================================================
class apb_monitor extends uvm_monitor;
    `uvm_component_utils(apb_monitor)

    virtual apb_if vif;
    uvm_analysis_port #(apb_txn) ap;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        ap = new("ap", this);
        if (!uvm_config_db #(virtual apb_if)::get(this, "", "vif", vif))
            `uvm_fatal(get_type_name(), "No virtual interface")
    endfunction

    virtual task run_phase(uvm_phase phase);
        apb_txn tr;
        forever begin
            @(vif.mon_cb iff (vif.mon_cb.psel && vif.mon_cb.penable && vif.mon_cb.pready));
            tr = apb_txn::type_id::create("mon_tr");
            tr.addr  = vif.mon_cb.paddr;
            tr.write = vif.mon_cb.pwrite;
            tr.data  = vif.mon_cb.pwrite ? vif.mon_cb.pwdata : vif.mon_cb.prdata;
            ap.write(tr);
        end
    endtask
endclass

// =============================================================================
//  Agent
// =============================================================================
class apb_agent extends uvm_agent;
    `uvm_component_utils(apb_agent)

    apb_driver                   drv;
    apb_monitor                  mon;
    uvm_sequencer #(apb_txn)    sqr;
    uvm_analysis_port #(apb_txn) ap;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        mon = apb_monitor::type_id::create("mon", this);
        if (get_is_active() == UVM_ACTIVE) begin
            drv = apb_driver::type_id::create("drv", this);
            sqr = uvm_sequencer#(apb_txn)::type_id::create("sqr", this);
        end
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        ap = mon.ap;
        if (get_is_active() == UVM_ACTIVE)
            drv.seq_item_port.connect(sqr.seq_item_export);
    endfunction
endclass

// =============================================================================
//  Scoreboard
// =============================================================================
class apb_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(apb_scoreboard)

    uvm_analysis_imp #(apb_txn, apb_scoreboard) imp;
    bit [31:0] ref_mem [bit[7:0]];
    int pass_cnt, fail_cnt, wr_cnt, rd_cnt;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        imp = new("imp", this);
    endfunction

    virtual function void write(apb_txn tr);
        if (tr.write) begin
            ref_mem[tr.addr] = tr.data;
            wr_cnt++;
        end else begin
            rd_cnt++;
            if (ref_mem.exists(tr.addr)) begin
                if (tr.data === ref_mem[tr.addr]) begin
                    pass_cnt++;
                    `uvm_info("SB", $sformatf("PASS [0x%02h] = 0x%08h", tr.addr, tr.data), UVM_HIGH)
                end else begin
                    fail_cnt++;
                    `uvm_error("SB", $sformatf("FAIL [0x%02h] exp=0x%08h got=0x%08h",
                               tr.addr, ref_mem[tr.addr], tr.data))
                end
            end
        end
    endfunction

    virtual function void report_phase(uvm_phase phase);
        `uvm_info("SB", $sformatf(
            "\n╔══════════════════════════╗\n║   SCOREBOARD SUMMARY    ║\n╠══════════════════════════╣\n║  Writes:    %4d        ║\n║  Reads:     %4d        ║\n║  Passes:    %4d        ║\n║  Failures:  %4d        ║\n╚══════════════════════════╝",
            wr_cnt, rd_cnt, pass_cnt, fail_cnt), UVM_LOW)
    endfunction
endclass

// =============================================================================
//  Functional Coverage
// =============================================================================
class apb_coverage extends uvm_subscriber #(apb_txn);
    `uvm_component_utils(apb_coverage)

    apb_txn tr;

    covergroup apb_cg;
        addr_cp:  coverpoint tr.addr {
            bins low    = {[8'h00:8'h3F]};
            bins mid    = {[8'h40:8'hBF]};
            bins high   = {[8'hC0:8'hFF]};
        }
        write_cp: coverpoint tr.write;
        cross addr_cp, write_cp;
    endgroup

    function new(string name, uvm_component parent);
        super.new(name, parent);
        apb_cg = new();
    endfunction

    virtual function void write(apb_txn t);
        tr = t;
        apb_cg.sample();
    endfunction

    virtual function void report_phase(uvm_phase phase);
        `uvm_info(get_type_name(), $sformatf("Coverage: %.1f%%",
                  apb_cg.get_inst_coverage()), UVM_LOW)
    endfunction
endclass

// =============================================================================
//  Environment
// =============================================================================
class apb_env extends uvm_env;
    `uvm_component_utils(apb_env)

    apb_agent       agt;
    apb_scoreboard  sb;
    apb_coverage    cov;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        agt = apb_agent::type_id::create("agt", this);
        sb  = apb_scoreboard::type_id::create("sb", this);
        cov = apb_coverage::type_id::create("cov", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        agt.ap.connect(sb.imp);
        agt.ap.connect(cov.analysis_export);
    endfunction
endclass

// =============================================================================
//  Tests
// =============================================================================
class apb_base_test extends uvm_test;
    `uvm_component_utils(apb_base_test)

    apb_env env;

    function new(string name = "apb_base_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = apb_env::type_id::create("env", this);
    endfunction

    virtual function void end_of_elaboration_phase(uvm_phase phase);
        uvm_top.print_topology();
    endfunction

    virtual function void report_phase(uvm_phase phase);
        uvm_report_server svr = uvm_report_server::get_server();
        if (svr.get_severity_count(UVM_ERROR) == 0 &&
            svr.get_severity_count(UVM_FATAL) == 0)
            `uvm_info(get_type_name(), "\n  *** TEST PASSED ***\n", UVM_NONE)
        else
            `uvm_info(get_type_name(), "\n  *** TEST FAILED ***\n", UVM_NONE)
    endfunction
endclass

// Write-read test
class apb_wr_rd_test extends apb_base_test;
    `uvm_component_utils(apb_wr_rd_test)

    function new(string name = "apb_wr_rd_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual task run_phase(uvm_phase phase);
        apb_wr_rd_seq seq;
        phase.raise_objection(this);
        seq = apb_wr_rd_seq::type_id::create("seq");
        seq.num_pairs = 15;
        seq.start(env.agt.sqr);
        #100;
        phase.drop_objection(this);
    endtask
endclass

// Random traffic test
class apb_random_test extends apb_base_test;
    `uvm_component_utils(apb_random_test)

    function new(string name = "apb_random_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual task run_phase(uvm_phase phase);
        apb_random_seq seq;
        phase.raise_objection(this);
        seq = apb_random_seq::type_id::create("seq");
        seq.count = 100;
        seq.start(env.agt.sqr);
        #200;
        phase.drop_objection(this);
    endtask
endclass

// =============================================================================
//  Top-Level Testbench Module
// =============================================================================
module tb_apb_complete;
    logic clk;

    apb_if bus(clk);

    apb_memory #(.ADDR_WIDTH(8), .DATA_WIDTH(32)) dut (
        .pclk     (clk),
        .preset_n (bus.preset_n),
        .psel     (bus.psel),
        .penable  (bus.penable),
        .pwrite   (bus.pwrite),
        .paddr    (bus.paddr),
        .pwdata   (bus.pwdata),
        .prdata   (bus.prdata),
        .pready   (bus.pready),
        .pslverr  (bus.pslverr)
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        bus.preset_n = 0;
        bus.psel     = 0;
        bus.penable  = 0;
        bus.pwrite   = 0;
        bus.paddr    = 0;
        bus.pwdata   = 0;
        #25;
        bus.preset_n = 1;
    end

    initial begin
        uvm_config_db #(virtual apb_if)::set(null, "*.agt.*", "vif", bus);
        run_test();  // test name from +UVM_TESTNAME
    end

    initial begin
        $dumpfile("apb_complete.vcd");
        $dumpvars(0, tb_apb_complete);
    end
endmodule
