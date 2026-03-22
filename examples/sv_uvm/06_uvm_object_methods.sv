// =============================================================================
// UVM Object Methods: do_copy, do_compare, do_print, convert2string
// =============================================================================
//
// Demonstrates the UVM uvm_object "do_*" hook pattern:
//   - do_copy()       — invoked by copy() / clone()
//   - do_compare()    — invoked by compare()
//   - do_print()      — invoked by print() / sprint()
//   - convert2string() — human-readable string
//   - pack / unpack   — serialization
//
// Requires: UVM library (compile with +incdir+$UVM_HOME/src $UVM_HOME/src/uvm_pkg.sv)

`include "uvm_macros.svh"
import uvm_pkg::*;

// ---- APB Transaction with full do_* implementations ----
class apb_txn extends uvm_sequence_item;
    `uvm_object_utils(apb_txn)

    rand bit [31:0] addr;
    rand bit [31:0] data;
    rand bit        write;
    rand bit [3:0]  strobe;
    bit             error;         // non-random: set by response

    constraint aligned_c {
        addr[1:0] == 0;
    }

    constraint strobe_c {
        write -> strobe != 0;
        !write -> strobe == 4'hF;
    }

    function new(string name = "apb_txn");
        super.new(name);
    endfunction

    // ---- do_copy ----
    virtual function void do_copy(uvm_object rhs);
        apb_txn rhs_;
        super.do_copy(rhs);
        if (!$cast(rhs_, rhs))
            `uvm_fatal("COPY", "Cast failed in do_copy")
        this.addr   = rhs_.addr;
        this.data   = rhs_.data;
        this.write  = rhs_.write;
        this.strobe = rhs_.strobe;
        this.error  = rhs_.error;
    endfunction

    // ---- do_compare ----
    virtual function bit do_compare(uvm_object rhs, uvm_comparer comparer);
        apb_txn rhs_;
        bit eq = super.do_compare(rhs, comparer);
        if (!$cast(rhs_, rhs))
            return 0;
        eq &= comparer.compare_field_int("addr",   this.addr,   rhs_.addr,   32);
        eq &= comparer.compare_field_int("data",   this.data,   rhs_.data,   32);
        eq &= comparer.compare_field_int("write",  this.write,  rhs_.write,   1);
        eq &= comparer.compare_field_int("strobe", this.strobe, rhs_.strobe,  4);
        eq &= comparer.compare_field_int("error",  this.error,  rhs_.error,   1);
        return eq;
    endfunction

    // ---- do_print ----
    virtual function void do_print(uvm_printer printer);
        super.do_print(printer);
        printer.print_field_int("addr",   addr,    32, UVM_HEX);
        printer.print_field_int("data",   data,    32, UVM_HEX);
        printer.print_field_int("write",  write,    1, UVM_BIN);
        printer.print_field_int("strobe", strobe,   4, UVM_HEX);
        printer.print_field_int("error",  error,    1, UVM_BIN);
    endfunction

    // ---- convert2string ----
    virtual function string convert2string();
        return $sformatf("APB %s ADDR=0x%08h DATA=0x%08h STRB=0x%01h%s",
                         write ? "WR" : "RD", addr, data, strobe,
                         error ? " [ERROR]" : "");
    endfunction
endclass

// ---- AXI Transaction (more complex, with dynamic arrays) ----
class axi_txn extends uvm_sequence_item;
    `uvm_object_utils(axi_txn)

    rand bit [31:0] addr;
    rand bit [3:0]  id;
    rand bit [7:0]  len;
    rand bit [2:0]  size;
    rand bit [1:0]  burst;
    rand bit        write;
    rand bit [31:0] data[];

    constraint basic_c {
        size <= 2;
        burst inside {0, 1, 2};
        data.size() == len + 1;
        len inside {[0:15]};
    }

    function new(string name = "axi_txn");
        super.new(name);
    endfunction

    virtual function void do_copy(uvm_object rhs);
        axi_txn rhs_;
        super.do_copy(rhs);
        $cast(rhs_, rhs);
        this.addr  = rhs_.addr;
        this.id    = rhs_.id;
        this.len   = rhs_.len;
        this.size  = rhs_.size;
        this.burst = rhs_.burst;
        this.write = rhs_.write;
        this.data  = new[rhs_.data.size()];
        foreach (rhs_.data[i])
            this.data[i] = rhs_.data[i];
    endfunction

    virtual function bit do_compare(uvm_object rhs, uvm_comparer comparer);
        axi_txn rhs_;
        bit eq = super.do_compare(rhs, comparer);
        $cast(rhs_, rhs);
        eq &= comparer.compare_field_int("addr",  this.addr,  rhs_.addr,  32);
        eq &= comparer.compare_field_int("id",    this.id,    rhs_.id,     4);
        eq &= comparer.compare_field_int("len",   this.len,   rhs_.len,    8);
        eq &= comparer.compare_field_int("size",  this.size,  rhs_.size,   3);
        eq &= comparer.compare_field_int("burst", this.burst, rhs_.burst,  2);
        eq &= comparer.compare_field_int("write", this.write, rhs_.write,  1);
        if (this.data.size() != rhs_.data.size())
            eq = 0;
        else
            foreach (this.data[i])
                eq &= comparer.compare_field_int(
                    $sformatf("data[%0d]", i), this.data[i], rhs_.data[i], 32);
        return eq;
    endfunction

    virtual function void do_print(uvm_printer printer);
        super.do_print(printer);
        printer.print_field_int("addr",  addr,  32, UVM_HEX);
        printer.print_field_int("id",    id,     4, UVM_DEC);
        printer.print_field_int("len",   len,    8, UVM_DEC);
        printer.print_field_int("size",  size,   3, UVM_DEC);
        printer.print_field_int("burst", burst,  2, UVM_DEC);
        printer.print_field_int("write", write,  1, UVM_BIN);
        foreach (data[i])
            printer.print_field_int($sformatf("data[%0d]", i), data[i], 32, UVM_HEX);
    endfunction

    virtual function string convert2string();
        string s = $sformatf("AXI %s ID=%0d ADDR=0x%08h LEN=%0d SIZE=%0d BURST=%0d",
                             write ? "WR" : "RD", id, addr, len, size, burst);
        foreach (data[i])
            s = {s, $sformatf("\n  [%0d] 0x%08h", i, data[i])};
        return s;
    endfunction
endclass

// ---- Demonstration test ----
class uvm_object_demo_test extends uvm_test;
    `uvm_component_utils(uvm_object_demo_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual task run_phase(uvm_phase phase);
        phase.raise_objection(this);

        demo_apb();
        demo_axi();

        phase.drop_objection(this);
    endtask

    function void demo_apb();
        apb_txn t1, t2, t3;

        `uvm_info("DEMO", "=== APB Transaction Demos ===", UVM_LOW)

        // Create and randomize
        t1 = apb_txn::type_id::create("t1");
        void'(t1.randomize() with { write == 1; addr == 32'h0000_1000; });
        t1.error = 0;

        // Print
        `uvm_info("DEMO", {"t1:\n", t1.convert2string()}, UVM_LOW)
        `uvm_info("DEMO", "t1 via print():", UVM_LOW)
        t1.print();

        // Copy
        t2 = apb_txn::type_id::create("t2");
        t2.copy(t1);
        `uvm_info("DEMO", {"t2 (copy of t1):\n", t2.convert2string()}, UVM_LOW)

        // Compare (should match)
        if (t1.compare(t2))
            `uvm_info("DEMO", "t1 == t2: MATCH", UVM_LOW)
        else
            `uvm_error("DEMO", "t1 != t2: UNEXPECTED MISMATCH")

        // Modify t2 and compare again
        t2.data = 32'hFFFF_FFFF;
        if (!t1.compare(t2))
            `uvm_info("DEMO", "t1 != t2 (after modify): EXPECTED MISMATCH", UVM_LOW)

        // Clone
        $cast(t3, t1.clone());
        `uvm_info("DEMO", {"t3 (clone of t1):\n", t3.convert2string()}, UVM_LOW)
    endfunction

    function void demo_axi();
        axi_txn a1, a2;

        `uvm_info("DEMO", "\n=== AXI Transaction Demos ===", UVM_LOW)

        a1 = axi_txn::type_id::create("a1");
        void'(a1.randomize() with { write == 1; len == 3; addr == 32'h0000_2000; });
        `uvm_info("DEMO", {"a1:\n", a1.convert2string()}, UVM_LOW)
        a1.print();

        // Clone and compare
        $cast(a2, a1.clone());
        if (a1.compare(a2))
            `uvm_info("DEMO", "a1 == a2 (clone): MATCH", UVM_LOW)

        // Modify one data beat
        a2.data[0] ^= 32'h1;
        if (!a1.compare(a2))
            `uvm_info("DEMO", "a1 != a2 (modified beat): EXPECTED MISMATCH", UVM_LOW)
    endfunction
endclass

module tb_uvm_object_methods;
    initial begin
        run_test("uvm_object_demo_test");
    end
endmodule
