// =============================================================================
// UVM Factory and Configuration Database
// =============================================================================
//
// Demonstrates:
//   - Factory registration with `uvm_object_utils / `uvm_component_utils
//   - Object creation via type_id::create()
//   - Type overrides: set_type_override
//   - Instance overrides: set_inst_override
//   - uvm_config_db::set / get
//   - Passing virtual interfaces and configuration objects
//   - Factory printing and debug

`include "uvm_macros.svh"
import uvm_pkg::*;

// ---- Configuration class ----
class my_config extends uvm_object;
    `uvm_object_utils(my_config)

    int unsigned  num_transactions = 10;
    bit           enable_coverage  = 1;
    bit [31:0]    base_address     = 32'h0;
    string        protocol         = "APB";

    function new(string name = "my_config");
        super.new(name);
    endfunction

    function string convert2string();
        return $sformatf("Config: proto=%s txns=%0d cov=%0b base=0x%08h",
                         protocol, num_transactions, enable_coverage, base_address);
    endfunction
endclass

// ---- Base transaction ----
class base_txn extends uvm_sequence_item;
    `uvm_object_utils(base_txn)

    rand bit [31:0] addr;
    rand bit [31:0] data;

    function new(string name = "base_txn");
        super.new(name);
    endfunction

    virtual function string convert2string();
        return $sformatf("base_txn: addr=0x%08h data=0x%08h", addr, data);
    endfunction
endclass

// ---- Extended transaction (for factory override) ----
class error_txn extends base_txn;
    `uvm_object_utils(error_txn)

    rand bit inject_error;
    rand bit [3:0] error_type;

    constraint error_dist_c {
        inject_error dist { 1 := 30, 0 := 70 };
        error_type inside {[0:3]};
    }

    function new(string name = "error_txn");
        super.new(name);
    endfunction

    virtual function string convert2string();
        string base_str = super.convert2string();
        return $sformatf("%s [error_txn: inject=%0b type=%0d]",
                         base_str, inject_error, error_type);
    endfunction
endclass

// ---- Base driver ----
class base_driver extends uvm_component;
    `uvm_component_utils(base_driver)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        `uvm_info(get_type_name(), "build_phase", UVM_LOW)
    endfunction

    virtual task run_phase(uvm_phase phase);
        `uvm_info(get_type_name(), "base_driver running", UVM_LOW)
    endtask
endclass

// ---- Enhanced driver (for factory override) ----
class enhanced_driver extends base_driver;
    `uvm_component_utils(enhanced_driver)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual task run_phase(uvm_phase phase);
        `uvm_info(get_type_name(), "enhanced_driver running (with pipelining!)", UVM_LOW)
    endtask
endclass

// ---- Simple environment ----
class my_env extends uvm_env;
    `uvm_component_utils(my_env)

    base_driver drv;
    my_config   cfg;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        // Get configuration from config_db
        if (!uvm_config_db #(my_config)::get(this, "", "cfg", cfg))
            `uvm_warning(get_type_name(), "No config found, using defaults")
        else
            `uvm_info(get_type_name(), {"Got config: ", cfg.convert2string()}, UVM_LOW)

        // Create driver via factory
        drv = base_driver::type_id::create("drv", this);
    endfunction
endclass

// ---- Test demonstrating factory and config_db ----
class factory_demo_test extends uvm_test;
    `uvm_component_utils(factory_demo_test)

    my_env env;

    function new(string name = "factory_demo_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        // --- Configure via config_db ---
        begin
            my_config cfg = my_config::type_id::create("cfg");
            cfg.num_transactions = 100;
            cfg.enable_coverage  = 0;
            cfg.base_address     = 32'h8000_0000;
            cfg.protocol         = "AXI";
            uvm_config_db #(my_config)::set(this, "env", "cfg", cfg);
        end

        // --- Factory type override ---
        // All base_driver creates will return enhanced_driver
        base_driver::type_id::set_type_override(enhanced_driver::get_type());

        // Create environment
        env = my_env::type_id::create("env", this);
    endfunction

    virtual task run_phase(uvm_phase phase);
        base_txn txns[$];

        phase.raise_objection(this);

        // --- Create transactions via factory ---
        `uvm_info(get_type_name(), "\n--- Creating base_txn via factory ---", UVM_LOW)
        repeat (3) begin
            base_txn t = base_txn::type_id::create("t");
            void'(t.randomize());
            `uvm_info(get_type_name(), t.convert2string(), UVM_LOW)
            txns.push_back(t);
        end

        // --- Now override base_txn -> error_txn ---
        `uvm_info(get_type_name(), "\n--- After type override: base_txn -> error_txn ---", UVM_LOW)
        base_txn::type_id::set_type_override(error_txn::get_type());

        repeat (3) begin
            base_txn t = base_txn::type_id::create("t");
            void'(t.randomize());
            `uvm_info(get_type_name(), t.convert2string(), UVM_LOW)
        end

        // --- Print factory state ---
        `uvm_info(get_type_name(), "\n--- Factory State ---", UVM_LOW)
        uvm_factory::get().print();

        phase.drop_objection(this);
    endtask

    virtual function void end_of_elaboration_phase(uvm_phase phase);
        `uvm_info(get_type_name(), "\n--- Component Topology ---", UVM_LOW)
        uvm_top.print_topology();
    endfunction
endclass

module tb_factory_config;
    initial begin
        run_test("factory_demo_test");
    end
endmodule
