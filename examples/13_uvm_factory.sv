// =============================================================================
// UVM Factory Example — Registration, Overrides, and Polymorphism
// =============================================================================
//
// Demonstrates:
//   - Registering components and objects with the factory
//   - Creating instances through type_id::create()
//   - Type overrides (global substitution)
//   - Instance overrides (targeted substitution)
//   - Override chaining
//   - Printing the factory state for debugging
//
// Hierarchy:
//   factory_test (uvm_test)
//     └─ env (pkt_env)
//          ├─ agent0 (pkt_agent) — may use overridden driver
//          │    ├─ driver
//          │    ├─ monitor
//          │    └─ sequencer
//          └─ agent1 (pkt_agent) — may use different overridden driver
//               ├─ driver
//               ├─ monitor
//               └─ sequencer
//
// =============================================================================

`include "uvm_macros.svh"
import uvm_pkg::*;

// =============================================================================
// TRANSACTION HIERARCHY
//
// base_packet
//   ├─ error_packet     (adds error injection fields)
//   └─ jumbo_packet     (increases max payload size)
//       └─ debug_packet (adds verbose tracing — override chain demo)
// =============================================================================

class base_packet extends uvm_sequence_item;
  `uvm_object_utils(base_packet)

  rand bit [47:0] src_addr;
  rand bit [47:0] dst_addr;
  rand bit [15:0] eth_type;
  rand byte       payload[];
  rand int        payload_len;

  constraint payload_size_c {
    payload_len inside {[46:1500]};
    payload.size() == payload_len;
  }

  function new(string name = "base_packet");
    super.new(name);
  endfunction

  function string convert2string();
    return $sformatf("[%s] src=%012h dst=%012h type=%04h len=%0d",
                     get_type_name(), src_addr, dst_addr, eth_type, payload_len);
  endfunction

  function void do_copy(uvm_object rhs);
    base_packet rhs_pkt;
    super.do_copy(rhs);
    $cast(rhs_pkt, rhs);
    src_addr    = rhs_pkt.src_addr;
    dst_addr    = rhs_pkt.dst_addr;
    eth_type    = rhs_pkt.eth_type;
    payload     = rhs_pkt.payload;
    payload_len = rhs_pkt.payload_len;
  endfunction
endclass

// Extended packet that can inject errors — used via type override in error tests
class error_packet extends base_packet;
  `uvm_object_utils(error_packet)

  rand bit inject_crc_error;
  rand bit inject_undersize;

  constraint error_rates_c {
    inject_crc_error dist {0 := 85, 1 := 15};
    inject_undersize dist {0 := 95, 1 := 5};
  }

  constraint undersize_c {
    if (inject_undersize)
      payload_len inside {[1:45]};
  }

  function new(string name = "error_packet");
    super.new(name);
  endfunction

  function string convert2string();
    return {super.convert2string(),
            $sformatf(" crc_err=%0b undersize=%0b", inject_crc_error, inject_undersize)};
  endfunction
endclass

// Jumbo packet — increases the max payload size
class jumbo_packet extends base_packet;
  `uvm_object_utils(jumbo_packet)

  constraint jumbo_size_c {
    payload_len inside {[1500:9000]};
  }

  function new(string name = "jumbo_packet");
    super.new(name);
  endfunction
endclass

// Debug packet — extends jumbo_packet; demonstrates override chaining
class debug_packet extends jumbo_packet;
  `uvm_object_utils(debug_packet)

  int unsigned sequence_number;
  static int unsigned global_seq_num = 0;

  function new(string name = "debug_packet");
    super.new(name);
    global_seq_num++;
    sequence_number = global_seq_num;
  endfunction

  function string convert2string();
    return {super.convert2string(), $sformatf(" seq#=%0d", sequence_number)};
  endfunction
endclass

// =============================================================================
// DRIVER HIERARCHY
//
// base_driver
//   ├─ slow_driver     (adds inter-frame gap)
//   └─ burst_driver    (removes all delays)
// =============================================================================

class base_driver extends uvm_driver#(base_packet);
  `uvm_component_utils(base_driver)

  int unsigned inter_frame_gap = 12;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    base_packet pkt;
    forever begin
      seq_item_port.get_next_item(pkt);
      drive(pkt);
      seq_item_port.item_done();
    end
  endtask

  virtual task drive(base_packet pkt);
    `uvm_info("BASE_DRV", $sformatf("Driving: %s (gap=%0d)",
              pkt.convert2string(), inter_frame_gap), UVM_MEDIUM)
    #(inter_frame_gap * 10);
  endtask
endclass

// Slow driver — inserts extra delay; useful for back-pressure testing
class slow_driver extends base_driver;
  `uvm_component_utils(slow_driver)

  function new(string name, uvm_component parent);
    super.new(name, parent);
    inter_frame_gap = 100;
  endfunction

  task drive(base_packet pkt);
    `uvm_info("SLOW_DRV", $sformatf("Slow-driving: %s (gap=%0d)",
              pkt.convert2string(), inter_frame_gap), UVM_MEDIUM)
    #(inter_frame_gap * 10);
  endtask
endclass

// Burst driver — zero delay; useful for throughput/stress testing
class burst_driver extends base_driver;
  `uvm_component_utils(burst_driver)

  function new(string name, uvm_component parent);
    super.new(name, parent);
    inter_frame_gap = 0;
  endfunction

  task drive(base_packet pkt);
    `uvm_info("BURST_DRV", $sformatf("Burst-driving: %s (no gap)",
              pkt.convert2string()), UVM_MEDIUM)
    #1;
  endtask
endclass

// =============================================================================
// SEQUENCE HIERARCHY
//
// base_sequence
//   └─ directed_sequence (sends specific patterns instead of random)
// =============================================================================

class base_sequence extends uvm_sequence#(base_packet);
  `uvm_object_utils(base_sequence)

  int unsigned count = 5;

  function new(string name = "base_sequence");
    super.new(name);
  endfunction

  task body();
    base_packet pkt;
    `uvm_info("SEQ", $sformatf("[%s] Generating %0d packets", get_type_name(), count), UVM_LOW)
    repeat (count) begin
      pkt = base_packet::type_id::create("pkt");
      start_item(pkt);
      if (!pkt.randomize())
        `uvm_error("RAND", "Packet randomization failed")
      finish_item(pkt);
    end
  endtask
endclass

class directed_sequence extends base_sequence;
  `uvm_object_utils(directed_sequence)

  function new(string name = "directed_sequence");
    super.new(name);
  endfunction

  task body();
    base_packet pkt;
    `uvm_info("DIR_SEQ", $sformatf("[%s] Sending directed patterns", get_type_name()), UVM_LOW)
    repeat (count) begin
      pkt = base_packet::type_id::create("pkt");
      start_item(pkt);
      if (!pkt.randomize() with {
        dst_addr == 48'hFFFF_FFFF_FFFF;
        eth_type == 16'h0800;
        payload_len == 64;
      })
        `uvm_error("RAND", "Directed randomization failed")
      finish_item(pkt);
    end
  endtask
endclass

// =============================================================================
// MONITOR & SCOREBOARD
// =============================================================================

class pkt_monitor extends uvm_monitor;
  `uvm_component_utils(pkt_monitor)

  uvm_analysis_port#(base_packet) ap;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    ap = new("ap", this);
  endfunction

  task run_phase(uvm_phase phase);
    `uvm_info("MON", "Monitor running", UVM_HIGH)
  endtask
endclass

class pkt_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(pkt_scoreboard)

  uvm_analysis_imp#(base_packet, pkt_scoreboard) analysis_export;
  int unsigned match_count;
  int unsigned mismatch_count;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    analysis_export = new("analysis_export", this);
  endfunction

  function void write(base_packet pkt);
    `uvm_info("SCB", $sformatf("Received: %s", pkt.convert2string()), UVM_HIGH)
    match_count++;
  endfunction

  function void report_phase(uvm_phase phase);
    `uvm_info("SCB", $sformatf("Matches: %0d, Mismatches: %0d",
              match_count, mismatch_count), UVM_LOW)
  endfunction
endclass

// =============================================================================
// AGENT & ENVIRONMENT
// =============================================================================

class pkt_agent extends uvm_agent;
  `uvm_component_utils(pkt_agent)

  base_driver                  driver;
  pkt_monitor                  monitor;
  uvm_sequencer#(base_packet)  sequencer;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    monitor   = pkt_monitor::type_id::create("monitor", this);
    driver    = base_driver::type_id::create("driver", this);
    sequencer = uvm_sequencer#(base_packet)::type_id::create("sequencer", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    driver.seq_item_port.connect(sequencer.seq_item_export);
  endfunction
endclass

class pkt_env extends uvm_env;
  `uvm_component_utils(pkt_env)

  pkt_agent      agent0;
  pkt_agent      agent1;
  pkt_scoreboard scoreboard;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    agent0     = pkt_agent::type_id::create("agent0", this);
    agent1     = pkt_agent::type_id::create("agent1", this);
    scoreboard = pkt_scoreboard::type_id::create("scoreboard", this);
  endfunction
endclass

// =============================================================================
// TESTS — Each demonstrates a different factory override pattern
// =============================================================================

// ---------------------
// Test 1: No overrides — baseline
// ---------------------
class baseline_test extends uvm_test;
  `uvm_component_utils(baseline_test)

  pkt_env env;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = pkt_env::type_id::create("env", this);
  endfunction

  task run_phase(uvm_phase phase);
    base_sequence seq;
    phase.raise_objection(this);

    seq = base_sequence::type_id::create("seq");
    seq.count = 3;
    seq.start(env.agent0.sequencer);

    phase.drop_objection(this);
  endtask

  function void end_of_elaboration_phase(uvm_phase phase);
    uvm_factory factory = uvm_factory::get();
    `uvm_info("TEST", "=== Factory State (Baseline) ===", UVM_LOW)
    factory.print();
  endfunction
endclass

// ---------------------
// Test 2: Type override — replace base_packet with error_packet everywhere
// ---------------------
class error_injection_test extends uvm_test;
  `uvm_component_utils(error_injection_test)

  pkt_env env;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    // TYPE OVERRIDE: Every create() of base_packet now returns error_packet
    base_packet::type_id::set_type_override(error_packet::get_type());

    super.build_phase(phase);
    env = pkt_env::type_id::create("env", this);
  endfunction

  task run_phase(uvm_phase phase);
    base_sequence seq;
    phase.raise_objection(this);

    seq = base_sequence::type_id::create("seq");
    seq.count = 5;
    seq.start(env.agent0.sequencer);

    phase.drop_objection(this);
  endtask

  function void end_of_elaboration_phase(uvm_phase phase);
    uvm_factory factory = uvm_factory::get();
    `uvm_info("TEST", "=== Factory State (Error Injection) ===", UVM_LOW)
    factory.print();
  endfunction
endclass

// ---------------------
// Test 3: Instance override — different drivers for different agents
// ---------------------
class mixed_driver_test extends uvm_test;
  `uvm_component_utils(mixed_driver_test)

  pkt_env env;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    // INSTANCE OVERRIDE: agent0 gets slow_driver, agent1 gets burst_driver
    base_driver::type_id::set_inst_override(
      slow_driver::get_type(),
      "uvm_test_top.env.agent0.driver"
    );

    base_driver::type_id::set_inst_override(
      burst_driver::get_type(),
      "uvm_test_top.env.agent1.driver"
    );

    super.build_phase(phase);
    env = pkt_env::type_id::create("env", this);
  endfunction

  task run_phase(uvm_phase phase);
    base_sequence seq0, seq1;
    phase.raise_objection(this);

    seq0 = base_sequence::type_id::create("seq0");
    seq0.count = 3;
    seq1 = base_sequence::type_id::create("seq1");
    seq1.count = 3;

    fork
      seq0.start(env.agent0.sequencer);
      seq1.start(env.agent1.sequencer);
    join

    phase.drop_objection(this);
  endtask

  function void end_of_elaboration_phase(uvm_phase phase);
    uvm_factory factory = uvm_factory::get();
    `uvm_info("TEST", "=== Factory State (Mixed Drivers) ===", UVM_LOW)
    factory.print();
  endfunction
endclass

// ---------------------
// Test 4: Override chaining — base_packet → jumbo_packet → debug_packet
// ---------------------
class override_chain_test extends uvm_test;
  `uvm_component_utils(override_chain_test)

  pkt_env env;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    // Chain: base_packet → jumbo_packet → debug_packet
    base_packet::type_id::set_type_override(jumbo_packet::get_type());
    jumbo_packet::type_id::set_type_override(debug_packet::get_type());

    // Also override the sequence
    base_sequence::type_id::set_type_override(directed_sequence::get_type());

    super.build_phase(phase);
    env = pkt_env::type_id::create("env", this);
  endfunction

  task run_phase(uvm_phase phase);
    base_sequence seq;
    phase.raise_objection(this);

    // create() returns directed_sequence due to override
    seq = base_sequence::type_id::create("seq");
    seq.count = 4;

    // The directed_sequence internally creates base_packet, which the factory
    // chains through to debug_packet
    seq.start(env.agent0.sequencer);

    phase.drop_objection(this);
  endtask

  function void end_of_elaboration_phase(uvm_phase phase);
    uvm_factory factory = uvm_factory::get();
    `uvm_info("TEST", "=== Factory State (Override Chain) ===", UVM_LOW)
    factory.print();
  endfunction
endclass

// ---------------------
// Test 5: Combined type + instance overrides, showing precedence
// ---------------------
class combined_override_test extends uvm_test;
  `uvm_component_utils(combined_override_test)

  pkt_env env;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    // TYPE OVERRIDE: all base_drivers become slow_drivers
    base_driver::type_id::set_type_override(slow_driver::get_type());

    // INSTANCE OVERRIDE: agent1's driver specifically becomes burst_driver
    // Instance overrides take precedence over type overrides
    base_driver::type_id::set_inst_override(
      burst_driver::get_type(),
      "uvm_test_top.env.agent1.driver"
    );

    super.build_phase(phase);
    env = pkt_env::type_id::create("env", this);
  endfunction

  task run_phase(uvm_phase phase);
    base_sequence seq0, seq1;
    phase.raise_objection(this);

    seq0 = base_sequence::type_id::create("seq0");
    seq0.count = 2;
    seq1 = base_sequence::type_id::create("seq1");
    seq1.count = 2;

    fork
      seq0.start(env.agent0.sequencer);  // slow_driver (type override)
      seq1.start(env.agent1.sequencer);  // burst_driver (instance override wins)
    join

    phase.drop_objection(this);
  endtask

  function void end_of_elaboration_phase(uvm_phase phase);
    uvm_factory factory = uvm_factory::get();
    `uvm_info("TEST", "=== Factory State (Combined Overrides) ===", UVM_LOW)
    factory.print();
    `uvm_info("TEST", "Note: agent0.driver is slow_driver (type override)", UVM_LOW)
    `uvm_info("TEST", "Note: agent1.driver is burst_driver (instance override wins)", UVM_LOW)
  endfunction
endclass

// =============================================================================
// Top-level Module
// =============================================================================
module tb_top;
  initial begin
    // Select which test to run via +UVM_TESTNAME=<test_name>
    // Examples:
    //   +UVM_TESTNAME=baseline_test
    //   +UVM_TESTNAME=error_injection_test
    //   +UVM_TESTNAME=mixed_driver_test
    //   +UVM_TESTNAME=override_chain_test
    //   +UVM_TESTNAME=combined_override_test
    run_test();
  end
endmodule
