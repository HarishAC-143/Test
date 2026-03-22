// UVM Transaction and Sequence Examples
// Demonstrates: uvm_sequence_item with do_* methods, uvm_sequence,
//               sequence-of-sequences, factory creation, field macros
//
// NOTE: This file requires a UVM library to compile. It is provided
//       as a reference/template for building UVM testbenches.

// ---------------------------------------------------------------------------
// APB Interface Definition
// ---------------------------------------------------------------------------
interface apb_if(input logic clk, input logic rst_n);
    logic        psel;
    logic        penable;
    logic        pwrite;
    logic [31:0] paddr;
    logic [31:0] pwdata;
    logic [31:0] prdata;
    logic        pready;
    logic        pslverr;

    clocking driver_cb @(posedge clk);
        output psel, penable, pwrite, paddr, pwdata;
        input  prdata, pready, pslverr;
    endclocking

    clocking monitor_cb @(posedge clk);
        input psel, penable, pwrite, paddr, pwdata, prdata, pready, pslverr;
    endclocking

    modport driver  (clocking driver_cb, input clk, rst_n);
    modport monitor (clocking monitor_cb, input clk, rst_n);
endinterface

// ---------------------------------------------------------------------------
// Package: all UVM components
// ---------------------------------------------------------------------------
package apb_uvm_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    // -----------------------------------------------------------------------
    // Transaction (uvm_sequence_item)
    // -----------------------------------------------------------------------
    class apb_transaction extends uvm_sequence_item;
        `uvm_object_utils(apb_transaction)

        rand bit [31:0] addr;
        rand bit [31:0] data;
        rand bit        write;
        bit             slverr;

        constraint addr_word_aligned {
            addr[1:0] == 2'b00;
        }

        constraint addr_range {
            addr inside {[32'h0000_0000 : 32'h0000_03FC]};
        }

        function new(string name = "apb_transaction");
            super.new(name);
        endfunction

        virtual function string convert2string();
            return $sformatf("%s addr=0x%08h data=0x%08h err=%0b",
                             write ? "WR" : "RD", addr, data, slverr);
        endfunction

        virtual function void do_copy(uvm_object rhs);
            apb_transaction rhs_;
            super.do_copy(rhs);
            if (!$cast(rhs_, rhs))
                `uvm_fatal("COPY", "Cast failed in do_copy")
            this.addr   = rhs_.addr;
            this.data   = rhs_.data;
            this.write  = rhs_.write;
            this.slverr = rhs_.slverr;
        endfunction

        virtual function bit do_compare(uvm_object rhs, uvm_comparer comparer);
            apb_transaction rhs_;
            if (!$cast(rhs_, rhs)) return 0;
            return (super.do_compare(rhs, comparer) &&
                    this.addr   == rhs_.addr &&
                    this.data   == rhs_.data &&
                    this.write  == rhs_.write);
        endfunction

        virtual function void do_print(uvm_printer printer);
            super.do_print(printer);
            printer.print_field_int("addr",   addr,   32, UVM_HEX);
            printer.print_field_int("data",   data,   32, UVM_HEX);
            printer.print_field_int("write",  write,   1, UVM_BIN);
            printer.print_field_int("slverr", slverr,  1, UVM_BIN);
        endfunction

        virtual function void do_pack(uvm_packer packer);
            super.do_pack(packer);
            packer.pack_field_int(addr,   32);
            packer.pack_field_int(data,   32);
            packer.pack_field_int(write,   1);
            packer.pack_field_int(slverr,  1);
        endfunction

        virtual function void do_unpack(uvm_packer packer);
            super.do_unpack(packer);
            addr   = packer.unpack_field_int(32);
            data   = packer.unpack_field_int(32);
            write  = packer.unpack_field_int(1);
            slverr = packer.unpack_field_int(1);
        endfunction
    endclass

    // -----------------------------------------------------------------------
    // Sequencer (simple typedef)
    // -----------------------------------------------------------------------
    typedef uvm_sequencer #(apb_transaction) apb_sequencer;

    // -----------------------------------------------------------------------
    // Sequences
    // -----------------------------------------------------------------------

    // Single write sequence
    class apb_write_seq extends uvm_sequence #(apb_transaction);
        `uvm_object_utils(apb_write_seq)

        rand bit [31:0] wr_addr;
        rand bit [31:0] wr_data;

        function new(string name = "apb_write_seq");
            super.new(name);
        endfunction

        virtual task body();
            apb_transaction txn;
            txn = apb_transaction::type_id::create("txn");
            start_item(txn);
            if (!txn.randomize() with {
                addr  == wr_addr;
                data  == wr_data;
                write == 1;
            })
                `uvm_fatal("SEQ", "Randomization failed")
            `uvm_info("WR_SEQ", txn.convert2string(), UVM_MEDIUM)
            finish_item(txn);
        endtask
    endclass

    // Single read sequence
    class apb_read_seq extends uvm_sequence #(apb_transaction);
        `uvm_object_utils(apb_read_seq)

        rand bit [31:0] rd_addr;
        bit [31:0]      rd_data;  // Captured after read completes

        function new(string name = "apb_read_seq");
            super.new(name);
        endfunction

        virtual task body();
            apb_transaction txn;
            txn = apb_transaction::type_id::create("txn");
            start_item(txn);
            if (!txn.randomize() with {
                addr  == rd_addr;
                write == 0;
            })
                `uvm_fatal("SEQ", "Randomization failed")
            finish_item(txn);
            rd_data = txn.data;
            `uvm_info("RD_SEQ", txn.convert2string(), UVM_MEDIUM)
        endtask
    endclass

    // Bulk write sequence — writes N random transactions
    class apb_bulk_write_seq extends uvm_sequence #(apb_transaction);
        `uvm_object_utils(apb_bulk_write_seq)

        rand int unsigned num_writes;

        constraint default_count {
            num_writes inside {[1:32]};
        }

        function new(string name = "apb_bulk_write_seq");
            super.new(name);
        endfunction

        virtual task body();
            apb_transaction txn;
            `uvm_info("BULK_WR", $sformatf("Starting %0d writes", num_writes), UVM_LOW)

            repeat (num_writes) begin
                txn = apb_transaction::type_id::create("txn");
                start_item(txn);
                if (!txn.randomize() with { write == 1; })
                    `uvm_fatal("SEQ", "Randomization failed")
                finish_item(txn);
            end

            `uvm_info("BULK_WR", $sformatf("Completed %0d writes", num_writes), UVM_LOW)
        endtask
    endclass

    // Write-then-read sequence — writes and reads back to verify
    class apb_write_read_seq extends uvm_sequence #(apb_transaction);
        `uvm_object_utils(apb_write_read_seq)

        rand int unsigned num_transactions;

        constraint default_count {
            num_transactions inside {[1:16]};
        }

        function new(string name = "apb_write_read_seq");
            super.new(name);
        endfunction

        virtual task body();
            apb_write_seq wr_seq;
            apb_read_seq  rd_seq;
            bit [31:0]    addresses[$];
            bit [31:0]    exp_data[$];

            `uvm_info("WR_RD", $sformatf("Starting %0d write/read pairs",
                      num_transactions), UVM_LOW)

            repeat (num_transactions) begin
                wr_seq = apb_write_seq::type_id::create("wr_seq");
                if (!wr_seq.randomize() with {
                    wr_addr[1:0] == 2'b00;
                    wr_addr inside {[0 : 32'h3FC]};
                })
                    `uvm_fatal("SEQ", "Randomization failed")
                wr_seq.start(m_sequencer);
                addresses.push_back(wr_seq.wr_addr);
                exp_data.push_back(wr_seq.wr_data);
            end

            foreach (addresses[i]) begin
                rd_seq = apb_read_seq::type_id::create("rd_seq");
                rd_seq.rd_addr = addresses[i];
                rd_seq.start(m_sequencer);

                if (rd_seq.rd_data !== exp_data[i])
                    `uvm_error("WR_RD", $sformatf(
                        "Read mismatch at addr=0x%08h: expected=0x%08h actual=0x%08h",
                        addresses[i], exp_data[i], rd_seq.rd_data))
                else
                    `uvm_info("WR_RD", $sformatf(
                        "Read match at addr=0x%08h: data=0x%08h",
                        addresses[i], rd_seq.rd_data), UVM_MEDIUM)
            end
        endtask
    endclass

    // -----------------------------------------------------------------------
    // Driver
    // -----------------------------------------------------------------------
    class apb_driver extends uvm_driver #(apb_transaction);
        `uvm_component_utils(apb_driver)

        virtual apb_if vif;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        virtual function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db #(virtual apb_if)::get(this, "", "vif", vif))
                `uvm_fatal("DRV", "Cannot get virtual interface from config_db")
        endfunction

        virtual task run_phase(uvm_phase phase);
            apb_transaction txn;
            forever begin
                seq_item_port.get_next_item(txn);
                drive(txn);
                seq_item_port.item_done();
            end
        endtask

        virtual task drive(apb_transaction txn);
            @(posedge vif.clk);
            vif.psel    <= 1;
            vif.paddr   <= txn.addr;
            vif.pwrite  <= txn.write;
            if (txn.write)
                vif.pwdata <= txn.data;

            @(posedge vif.clk);
            vif.penable <= 1;

            do @(posedge vif.clk);
            while (!vif.pready);

            if (!txn.write)
                txn.data = vif.prdata;
            txn.slverr = vif.pslverr;

            vif.psel    <= 0;
            vif.penable <= 0;
        endtask
    endclass

    // -----------------------------------------------------------------------
    // Monitor
    // -----------------------------------------------------------------------
    class apb_monitor extends uvm_monitor;
        `uvm_component_utils(apb_monitor)

        virtual apb_if vif;
        uvm_analysis_port #(apb_transaction) ap;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        virtual function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            ap = new("ap", this);
            if (!uvm_config_db #(virtual apb_if)::get(this, "", "vif", vif))
                `uvm_fatal("MON", "Cannot get virtual interface from config_db")
        endfunction

        virtual task run_phase(uvm_phase phase);
            forever begin
                apb_transaction txn;
                collect(txn);
                ap.write(txn);
            end
        endtask

        virtual task collect(output apb_transaction txn);
            txn = apb_transaction::type_id::create("txn");

            @(posedge vif.clk);
            wait(vif.psel && vif.penable && vif.pready);

            txn.addr   = vif.paddr;
            txn.write  = vif.pwrite;
            txn.data   = vif.pwrite ? vif.pwdata : vif.prdata;
            txn.slverr = vif.pslverr;

            `uvm_info("MON", txn.convert2string(), UVM_HIGH)
        endtask
    endclass

    // -----------------------------------------------------------------------
    // Agent
    // -----------------------------------------------------------------------
    class apb_agent extends uvm_agent;
        `uvm_component_utils(apb_agent)

        apb_driver    drv;
        apb_sequencer sqr;
        apb_monitor   mon;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        virtual function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            mon = apb_monitor::type_id::create("mon", this);

            if (get_is_active() == UVM_ACTIVE) begin
                drv = apb_driver::type_id::create("drv", this);
                sqr = apb_sequencer::type_id::create("sqr", this);
            end
        endfunction

        virtual function void connect_phase(uvm_phase phase);
            super.connect_phase(phase);
            if (get_is_active() == UVM_ACTIVE)
                drv.seq_item_port.connect(sqr.seq_item_export);
        endfunction
    endclass

    // -----------------------------------------------------------------------
    // Scoreboard
    // -----------------------------------------------------------------------
    class apb_scoreboard extends uvm_scoreboard;
        `uvm_component_utils(apb_scoreboard)

        uvm_analysis_imp #(apb_transaction, apb_scoreboard) ap_imp;

        bit [31:0] mem_model[bit [31:0]];
        int        match_count;
        int        mismatch_count;
        int        write_count;
        int        read_count;

        function new(string name, uvm_component parent);
            super.new(name, parent);
            match_count    = 0;
            mismatch_count = 0;
            write_count    = 0;
            read_count     = 0;
        endfunction

        virtual function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            ap_imp = new("ap_imp", this);
        endfunction

        virtual function void write(apb_transaction txn);
            if (txn.write) begin
                mem_model[txn.addr] = txn.data;
                write_count++;
                `uvm_info("SCB", $sformatf("WRITE: %s — stored", txn.convert2string()), UVM_MEDIUM)
            end else begin
                read_count++;
                if (mem_model.exists(txn.addr)) begin
                    if (txn.data === mem_model[txn.addr]) begin
                        match_count++;
                        `uvm_info("SCB", $sformatf("READ MATCH: %s", txn.convert2string()), UVM_MEDIUM)
                    end else begin
                        mismatch_count++;
                        `uvm_error("SCB", $sformatf(
                            "MISMATCH addr=0x%08h exp=0x%08h act=0x%08h",
                            txn.addr, mem_model[txn.addr], txn.data))
                    end
                end else begin
                    `uvm_warning("SCB", $sformatf("READ from unwritten addr=0x%08h", txn.addr))
                end
            end
        endfunction

        virtual function void report_phase(uvm_phase phase);
            super.report_phase(phase);
            `uvm_info("SCB", $sformatf(
                "\n  === Scoreboard Summary ===\n" +
                "  Writes:     %0d\n" +
                "  Reads:      %0d\n" +
                "  Matches:    %0d\n" +
                "  Mismatches: %0d\n" +
                "  Result:     %s",
                write_count, read_count, match_count, mismatch_count,
                (mismatch_count == 0) ? "PASS" : "FAIL"), UVM_NONE)
        endfunction
    endclass

    // -----------------------------------------------------------------------
    // Environment
    // -----------------------------------------------------------------------
    class apb_env extends uvm_env;
        `uvm_component_utils(apb_env)

        apb_agent      agent;
        apb_scoreboard scoreboard;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        virtual function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            agent      = apb_agent::type_id::create("agent", this);
            scoreboard = apb_scoreboard::type_id::create("scoreboard", this);
        endfunction

        virtual function void connect_phase(uvm_phase phase);
            super.connect_phase(phase);
            agent.mon.ap.connect(scoreboard.ap_imp);
        endfunction
    endclass

    // -----------------------------------------------------------------------
    // Tests
    // -----------------------------------------------------------------------
    class apb_base_test extends uvm_test;
        `uvm_component_utils(apb_base_test)

        apb_env env;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        virtual function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            env = apb_env::type_id::create("env", this);
        endfunction

        virtual function void end_of_elaboration_phase(uvm_phase phase);
            super.end_of_elaboration_phase(phase);
            uvm_top.print_topology();
        endfunction
    endclass

    class apb_write_read_test extends apb_base_test;
        `uvm_component_utils(apb_write_read_test)

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        virtual task run_phase(uvm_phase phase);
            apb_write_read_seq seq;

            phase.raise_objection(this);

            seq = apb_write_read_seq::type_id::create("seq");
            seq.num_transactions = 20;
            seq.start(env.agent.sqr);

            #100;
            phase.drop_objection(this);
        endtask
    endclass

    class apb_bulk_write_test extends apb_base_test;
        `uvm_component_utils(apb_bulk_write_test)

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        virtual task run_phase(uvm_phase phase);
            apb_bulk_write_seq seq;

            phase.raise_objection(this);

            seq = apb_bulk_write_seq::type_id::create("seq");
            seq.num_writes = 50;
            seq.start(env.agent.sqr);

            #100;
            phase.drop_objection(this);
        endtask
    endclass

endpackage

// ---------------------------------------------------------------------------
// Simple APB Slave DUT
// ---------------------------------------------------------------------------
module apb_slave (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        psel,
    input  logic        penable,
    input  logic        pwrite,
    input  logic [31:0] paddr,
    input  logic [31:0] pwdata,
    output logic [31:0] prdata,
    output logic        pready,
    output logic        pslverr
);
    logic [31:0] mem [0:255];

    assign pslverr = 0;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pready <= 0;
            prdata <= 0;
        end else begin
            if (psel && penable) begin
                pready <= 1;
                if (pwrite)
                    mem[paddr[9:2]] <= pwdata;
                else
                    prdata <= mem[paddr[9:2]];
            end else begin
                pready <= 0;
            end
        end
    end
endmodule

// ---------------------------------------------------------------------------
// Top-level Testbench
// ---------------------------------------------------------------------------
module tb_top;
    import uvm_pkg::*;
    import apb_uvm_pkg::*;
    `include "uvm_macros.svh"

    logic clk   = 0;
    logic rst_n = 0;

    always #5 clk = ~clk;

    apb_if apb_intf(clk, rst_n);

    apb_slave dut (
        .clk     (clk),
        .rst_n   (rst_n),
        .psel    (apb_intf.psel),
        .penable (apb_intf.penable),
        .pwrite  (apb_intf.pwrite),
        .paddr   (apb_intf.paddr),
        .pwdata  (apb_intf.pwdata),
        .prdata  (apb_intf.prdata),
        .pready  (apb_intf.pready),
        .pslverr (apb_intf.pslverr)
    );

    initial begin
        uvm_config_db #(virtual apb_if)::set(null, "uvm_test_top.*", "vif", apb_intf);
        run_test();
    end

    initial begin
        rst_n = 0;
        repeat (10) @(posedge clk);
        rst_n = 1;
    end
endmodule
