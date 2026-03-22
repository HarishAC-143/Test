// =============================================================================
// UVM TLM Communication: Analysis Ports, FIFOs, and Multi-Port Scoreboards
// =============================================================================
//
// Demonstrates:
//   - uvm_analysis_port / uvm_analysis_imp
//   - uvm_analysis_imp_decl for multiple write() functions
//   - uvm_tlm_analysis_fifo for buffered communication
//   - Producer-consumer patterns
//   - Broadcast (1-to-many) communication

`include "uvm_macros.svh"
import uvm_pkg::*;

// ---- Transaction ----
class data_txn extends uvm_object;
    `uvm_object_utils(data_txn)

    int          id;
    bit [31:0]   value;
    string       source;
    int          timestamp;

    function new(string name = "data_txn");
        super.new(name);
    endfunction

    virtual function string convert2string();
        return $sformatf("[%s #%0d] val=0x%08h t=%0d", source, id, value, timestamp);
    endfunction

    virtual function void do_copy(uvm_object rhs);
        data_txn t;
        super.do_copy(rhs);
        $cast(t, rhs);
        id        = t.id;
        value     = t.value;
        source    = t.source;
        timestamp = t.timestamp;
    endfunction
endclass

// ---- Producer: generates transactions and broadcasts via analysis port ----
class producer extends uvm_component;
    `uvm_component_utils(producer)

    uvm_analysis_port #(data_txn) ap;
    string producer_name;
    int count;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        producer_name = name;
        count = 5;
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        ap = new("ap", this);
    endfunction

    virtual task run_phase(uvm_phase phase);
        data_txn tr;
        phase.raise_objection(this);

        for (int i = 0; i < count; i++) begin
            tr = data_txn::type_id::create("tr");
            tr.id        = i;
            tr.value     = $urandom();
            tr.source    = producer_name;
            tr.timestamp = $time;
            `uvm_info(get_type_name(), {"Broadcasting: ", tr.convert2string()}, UVM_MEDIUM)
            ap.write(tr);
            #10;
        end

        phase.drop_objection(this);
    endtask
endclass

// ---- Simple subscriber using analysis_imp ----
class simple_subscriber extends uvm_component;
    `uvm_component_utils(simple_subscriber)

    uvm_analysis_imp #(data_txn, simple_subscriber) imp;
    int received_count;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        received_count = 0;
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        imp = new("imp", this);
    endfunction

    virtual function void write(data_txn tr);
        received_count++;
        `uvm_info(get_type_name(), $sformatf("Received [%0d]: %s",
                  received_count, tr.convert2string()), UVM_MEDIUM)
    endfunction

    virtual function void report_phase(uvm_phase phase);
        `uvm_info(get_type_name(), $sformatf("Total received: %0d", received_count), UVM_LOW)
    endfunction
endclass

// ---- Multi-port subscriber using uvm_analysis_imp_decl ----
`uvm_analysis_imp_decl(_input_a)
`uvm_analysis_imp_decl(_input_b)

class multi_port_checker extends uvm_component;
    `uvm_component_utils(multi_port_checker)

    uvm_analysis_imp_input_a #(data_txn, multi_port_checker) port_a;
    uvm_analysis_imp_input_b #(data_txn, multi_port_checker) port_b;

    data_txn a_queue[$];
    data_txn b_queue[$];
    int match_count, mismatch_count;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        match_count    = 0;
        mismatch_count = 0;
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        port_a = new("port_a", this);
        port_b = new("port_b", this);
    endfunction

    function void write_input_a(data_txn tr);
        data_txn copy;
        $cast(copy, tr.clone());
        a_queue.push_back(copy);
        `uvm_info(get_type_name(), {"Port A got: ", tr.convert2string()}, UVM_HIGH)
        try_compare();
    endfunction

    function void write_input_b(data_txn tr);
        data_txn copy;
        $cast(copy, tr.clone());
        b_queue.push_back(copy);
        `uvm_info(get_type_name(), {"Port B got: ", tr.convert2string()}, UVM_HIGH)
        try_compare();
    endfunction

    function void try_compare();
        data_txn a_item, b_item;
        while (a_queue.size() > 0 && b_queue.size() > 0) begin
            a_item = a_queue.pop_front();
            b_item = b_queue.pop_front();
            if (a_item.value == b_item.value) begin
                match_count++;
                `uvm_info(get_type_name(), $sformatf("MATCH #%0d: 0x%08h",
                          a_item.id, a_item.value), UVM_MEDIUM)
            end else begin
                mismatch_count++;
                `uvm_error(get_type_name(), $sformatf("MISMATCH #%0d: A=0x%08h B=0x%08h",
                           a_item.id, a_item.value, b_item.value))
            end
        end
    endfunction

    virtual function void report_phase(uvm_phase phase);
        `uvm_info(get_type_name(), $sformatf(
            "\n--- Multi-Port Checker ---\nMatches:    %0d\nMismatches: %0d\nA pending:  %0d\nB pending:  %0d",
            match_count, mismatch_count, a_queue.size(), b_queue.size()), UVM_LOW)
    endfunction
endclass

// ---- FIFO-based consumer ----
class fifo_consumer extends uvm_component;
    `uvm_component_utils(fifo_consumer)

    uvm_tlm_analysis_fifo #(data_txn) fifo;
    int processed;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        processed = 0;
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        fifo = new("fifo", this);
    endfunction

    virtual task run_phase(uvm_phase phase);
        data_txn tr;
        phase.raise_objection(this);

        // Process items from the FIFO with some delay
        forever begin
            if (!fifo.try_get(tr)) begin
                #5;
                if (!fifo.try_get(tr)) begin
                    if (processed > 0) break;
                    #10;
                    continue;
                end
            end
            processed++;
            `uvm_info(get_type_name(), $sformatf("Processed [%0d]: %s",
                      processed, tr.convert2string()), UVM_MEDIUM)
            #2;
        end

        phase.drop_objection(this);
    endtask

    virtual function void report_phase(uvm_phase phase);
        `uvm_info(get_type_name(), $sformatf("Total processed: %0d", processed), UVM_LOW)
    endfunction
endclass

// ---- Environment ----
class tlm_env extends uvm_env;
    `uvm_component_utils(tlm_env)

    producer           prod;
    simple_subscriber  sub1;
    simple_subscriber  sub2;
    fifo_consumer      fifo_cons;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        prod      = producer::type_id::create("prod", this);
        sub1      = simple_subscriber::type_id::create("sub1", this);
        sub2      = simple_subscriber::type_id::create("sub2", this);
        fifo_cons = fifo_consumer::type_id::create("fifo_cons", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        // One producer broadcasting to two subscribers and a FIFO consumer
        prod.ap.connect(sub1.imp);
        prod.ap.connect(sub2.imp);
        prod.ap.connect(fifo_cons.fifo.analysis_export);
    endfunction
endclass

// ---- Test ----
class tlm_demo_test extends uvm_test;
    `uvm_component_utils(tlm_demo_test)

    tlm_env env;

    function new(string name = "tlm_demo_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = tlm_env::type_id::create("env", this);
    endfunction

    virtual function void end_of_elaboration_phase(uvm_phase phase);
        uvm_top.print_topology();
    endfunction
endclass

module tb_tlm_analysis;
    initial begin
        run_test("tlm_demo_test");
    end
endmodule
