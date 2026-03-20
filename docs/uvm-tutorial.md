# Comprehensive UVM Tutorial: From Basics to Advanced

## Table of Contents

1. [Introduction to UVM](#1-introduction-to-uvm)
2. [UVM Architecture Overview](#2-uvm-architecture-overview)
3. [UVM Base Classes](#3-uvm-base-classes)
4. [UVM Testbench Components](#4-uvm-testbench-components)
5. [UVM Sequences and Sequence Items](#5-uvm-sequences-and-sequence-items)
6. [UVM Phases](#6-uvm-phases)
7. [UVM Configuration Database](#7-uvm-configuration-database)
8. [UVM Factory](#8-uvm-factory)
9. [TLM (Transaction Level Modeling)](#9-tlm-transaction-level-modeling)
10. [UVM Reporting and Messaging](#10-uvm-reporting-and-messaging)
11. [UVM Register Abstraction Layer (RAL)](#11-uvm-register-abstraction-layer-ral)
12. [Advanced: Callbacks](#12-advanced-callbacks)
13. [Advanced: Virtual Sequences and Virtual Sequencers](#13-advanced-virtual-sequences-and-virtual-sequencers)
14. [Advanced: Coverage-Driven Verification](#14-advanced-coverage-driven-verification)
15. [Advanced: Scoreboards and Checkers](#15-advanced-scoreboards-and-checkers)
16. [Practical Examples](#16-practical-examples)
17. [Common Pitfalls and Best Practices](#17-common-pitfalls-and-best-practices)

---

## 1. Introduction to UVM

### What is UVM?

The **Universal Verification Methodology (UVM)** is a standardized methodology for verifying digital designs using SystemVerilog. It provides a framework of base classes, utilities, and conventions that enable engineers to build reusable, scalable verification environments.

### Why UVM?

| Benefit | Description |
|---------|-------------|
| **Reusability** | Components can be reused across projects with minimal modification |
| **Scalability** | Testbenches scale from block-level to SoC-level verification |
| **Standardization** | IEEE 1800.2 standard ensures portability across tools and teams |
| **Automation** | Built-in factory, configuration, and phasing reduce boilerplate |
| **Constrained Random** | Powerful stimulus generation through sequences and constraints |

### Prerequisites

- Solid understanding of SystemVerilog (classes, interfaces, constraints, covergroups)
- Familiarity with object-oriented programming concepts
- Basic understanding of digital design verification concepts

---

## 2. UVM Architecture Overview

A typical UVM testbench follows a layered architecture:

```
┌─────────────────────────────────────────────┐
│                   Test                       │
│  ┌───────────────────────────────────────┐   │
│  │             Environment               │   │
│  │  ┌─────────────┐  ┌───────────────┐   │   │
│  │  │    Agent     │  │  Scoreboard   │   │   │
│  │  │ ┌─────────┐ │  │               │   │   │
│  │  │ │Sequencer│ │  └───────────────┘   │   │
│  │  │ ├─────────┤ │                      │   │
│  │  │ │ Driver  │ │  ┌───────────────┐   │   │
│  │  │ ├─────────┤ │  │   Coverage    │   │   │
│  │  │ │ Monitor │ │  │   Collector   │   │   │
│  │  │ └─────────┘ │  └───────────────┘   │   │
│  │  └─────────────┘                      │   │
│  └───────────────────────────────────────┘   │
│                     │ (virtual interface)     │
├─────────────────────┼───────────────────────┤
│                     ▼                        │
│              DUT (Design Under Test)         │
└─────────────────────────────────────────────┘
```

### Key Components

- **Test**: Top-level component that configures and starts the environment
- **Environment (Env)**: Container for agents, scoreboards, and coverage
- **Agent**: Encapsulates driver, sequencer, and monitor for a single interface
- **Driver**: Converts transactions into pin-level activity on the DUT
- **Monitor**: Observes pin-level activity and converts it to transactions
- **Sequencer**: Routes sequence items from sequences to the driver
- **Scoreboard**: Checks DUT output correctness
- **Sequences**: Generate stimulus (transaction streams)
- **Sequence Items**: Individual transaction data objects

---

## 3. UVM Base Classes

UVM provides a rich class hierarchy. Understanding it is key to using UVM effectively.

### Class Hierarchy

```
uvm_void
  └── uvm_object
        ├── uvm_transaction
        │     └── uvm_sequence_item
        ├── uvm_sequence
        ├── uvm_report_object
        │     └── uvm_component
        │           ├── uvm_driver
        │           ├── uvm_monitor
        │           ├── uvm_sequencer
        │           ├── uvm_agent
        │           ├── uvm_env
        │           ├── uvm_test
        │           └── uvm_scoreboard
        └── uvm_reg (register model classes)
```

### uvm_object

The `uvm_object` is the base class for all UVM data and hierarchical classes. It provides core utility methods:

```systemverilog
class my_object extends uvm_object;
  `uvm_object_utils(my_object)

  int data;
  string name;

  function new(string name = "my_object");
    super.new(name);
  endfunction

  // Core utility methods to implement:
  // - do_copy()    : Deep copy
  // - do_compare() : Field-by-field comparison
  // - do_print()   : Custom print
  // - do_pack()    : Serialize to bits
  // - do_unpack()  : Deserialize from bits
  // - convert2string() : String representation
endclass
```

### uvm_component

The `uvm_component` is the base class for all structural testbench elements. Unlike `uvm_object`, components:
- Exist in a hierarchy (parent-child relationships)
- Have phases (build, connect, run, etc.)
- Persist for the entire simulation

```systemverilog
class my_component extends uvm_component;
  `uvm_component_utils(my_component)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    // Build child components here
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    // Connect TLM ports here
  endfunction

  task run_phase(uvm_phase phase);
    // Main execution logic
  endtask
endclass
```

### Field Automation Macros

UVM provides field macros for automatic implementation of `copy`, `compare`, `print`, `pack`, and `unpack`:

```systemverilog
class my_transaction extends uvm_sequence_item;
  rand bit [7:0]  addr;
  rand bit [31:0] data;
  rand bit        write;

  `uvm_object_utils_begin(my_transaction)
    `uvm_field_int(addr,  UVM_ALL_ON)
    `uvm_field_int(data,  UVM_ALL_ON)
    `uvm_field_int(write, UVM_ALL_ON)
  `uvm_object_utils_end

  function new(string name = "my_transaction");
    super.new(name);
  endfunction
endclass
```

> **Note**: While field macros are convenient, they carry performance overhead. For high-performance testbenches, implement `do_copy()`, `do_compare()`, etc. manually.

---

## 4. UVM Testbench Components

### 4.1 Sequence Item

The sequence item is the fundamental data object that flows through the testbench:

```systemverilog
class apb_seq_item extends uvm_sequence_item;
  `uvm_object_utils(apb_seq_item)

  rand bit [31:0] addr;
  rand bit [31:0] data;
  rand bit        write;
  bit [31:0]      rdata;   // Response data (not randomized)

  constraint addr_range_c {
    addr inside {[32'h0000_0000 : 32'h0000_FFFF]};
  }

  constraint data_range_c {
    data inside {[0:255]};
  }

  function new(string name = "apb_seq_item");
    super.new(name);
  endfunction

  function string convert2string();
    return $sformatf("addr=0x%08h data=0x%08h write=%0b rdata=0x%08h",
                     addr, data, write, rdata);
  endfunction
endclass
```

### 4.2 Driver

The driver receives transactions from the sequencer and drives them onto the DUT interface:

```systemverilog
class apb_driver extends uvm_driver #(apb_seq_item);
  `uvm_component_utils(apb_driver)

  virtual apb_if vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual apb_if)::get(this, "", "vif", vif))
      `uvm_fatal("NO_VIF", "Virtual interface not found in config_db")
  endfunction

  task run_phase(uvm_phase phase);
    apb_seq_item req;
    forever begin
      seq_item_port.get_next_item(req);
      drive_transaction(req);
      seq_item_port.item_done();
    end
  endtask

  task drive_transaction(apb_seq_item tr);
    @(posedge vif.pclk);
    vif.paddr  <= tr.addr;
    vif.pwdata <= tr.data;
    vif.pwrite <= tr.write;
    vif.psel   <= 1'b1;

    @(posedge vif.pclk);
    vif.penable <= 1'b1;

    @(posedge vif.pclk);
    while (!vif.pready) @(posedge vif.pclk);

    if (!tr.write)
      tr.rdata = vif.prdata;

    vif.psel    <= 1'b0;
    vif.penable <= 1'b0;
  endtask
endclass
```

### 4.3 Monitor

The monitor passively observes interface activity:

```systemverilog
class apb_monitor extends uvm_monitor;
  `uvm_component_utils(apb_monitor)

  virtual apb_if vif;

  uvm_analysis_port #(apb_seq_item) analysis_port;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    analysis_port = new("analysis_port", this);
    if (!uvm_config_db#(virtual apb_if)::get(this, "", "vif", vif))
      `uvm_fatal("NO_VIF", "Virtual interface not found")
  endfunction

  task run_phase(uvm_phase phase);
    forever begin
      apb_seq_item tr = apb_seq_item::type_id::create("tr");
      collect_transaction(tr);
      analysis_port.write(tr);
    end
  endtask

  task collect_transaction(apb_seq_item tr);
    @(posedge vif.pclk iff vif.psel);
    tr.addr  = vif.paddr;
    tr.data  = vif.pwdata;
    tr.write = vif.pwrite;

    @(posedge vif.pclk iff vif.pready);
    if (!tr.write)
      tr.rdata = vif.prdata;

    `uvm_info("MON", $sformatf("Collected: %s", tr.convert2string()), UVM_MEDIUM)
  endtask
endclass
```

### 4.4 Sequencer

The sequencer is a parameterized arbiter that routes sequence items:

```systemverilog
class apb_sequencer extends uvm_sequencer #(apb_seq_item);
  `uvm_component_utils(apb_sequencer)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
endclass
```

### 4.5 Agent

The agent encapsulates the driver, monitor, and sequencer. It can be configured as `UVM_ACTIVE` (drives stimulus) or `UVM_PASSIVE` (only monitors):

```systemverilog
class apb_agent extends uvm_agent;
  `uvm_component_utils(apb_agent)

  apb_driver    drv;
  apb_monitor   mon;
  apb_sequencer sqr;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    mon = apb_monitor::type_id::create("mon", this);

    if (get_is_active() == UVM_ACTIVE) begin
      drv = apb_driver::type_id::create("drv", this);
      sqr = apb_sequencer::type_id::create("sqr", this);
    end
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    if (get_is_active() == UVM_ACTIVE)
      drv.seq_item_port.connect(sqr.seq_item_export);
  endfunction
endclass
```

### 4.6 Environment

The environment is the top-level container for all testbench components:

```systemverilog
class apb_env extends uvm_env;
  `uvm_component_utils(apb_env)

  apb_agent     agent;
  apb_scoreboard scoreboard;
  apb_coverage   coverage;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    agent      = apb_agent::type_id::create("agent", this);
    scoreboard = apb_scoreboard::type_id::create("scoreboard", this);
    coverage   = apb_coverage::type_id::create("coverage", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    agent.mon.analysis_port.connect(scoreboard.analysis_export);
    agent.mon.analysis_port.connect(coverage.analysis_export);
  endfunction
endclass
```

### 4.7 Test

The test is the top of the UVM hierarchy:

```systemverilog
class apb_base_test extends uvm_test;
  `uvm_component_utils(apb_base_test)

  apb_env env;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = apb_env::type_id::create("env", this);
  endfunction

  function void end_of_elaboration_phase(uvm_phase phase);
    uvm_top.print_topology();
  endfunction
endclass

class apb_write_test extends apb_base_test;
  `uvm_component_utils(apb_write_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    apb_write_seq seq = apb_write_seq::type_id::create("seq");
    phase.raise_objection(this);
    seq.start(env.agent.sqr);
    phase.drop_objection(this);
  endtask
endclass
```

---

## 5. UVM Sequences and Sequence Items

Sequences are the primary mechanism for generating stimulus in UVM.

### 5.1 Basic Sequence

```systemverilog
class apb_write_seq extends uvm_sequence #(apb_seq_item);
  `uvm_object_utils(apb_write_seq)

  function new(string name = "apb_write_seq");
    super.new(name);
  endfunction

  task body();
    apb_seq_item req;

    repeat(10) begin
      req = apb_seq_item::type_id::create("req");
      start_item(req);
      if (!req.randomize() with { write == 1; })
        `uvm_error("RAND_FAIL", "Randomization failed")
      finish_item(req);
    end
  endtask
endclass
```

### 5.2 Sequence with Response

```systemverilog
class apb_read_seq extends uvm_sequence #(apb_seq_item);
  `uvm_object_utils(apb_read_seq)

  bit [31:0] read_addr;
  bit [31:0] read_data;

  function new(string name = "apb_read_seq");
    super.new(name);
  endfunction

  task body();
    apb_seq_item req;
    req = apb_seq_item::type_id::create("req");

    start_item(req);
    req.addr  = read_addr;
    req.write = 0;
    finish_item(req);

    read_data = req.rdata;
    `uvm_info("READ_SEQ", $sformatf("Read 0x%08h from 0x%08h",
              read_data, read_addr), UVM_MEDIUM)
  endtask
endclass
```

### 5.3 Sequence Hierarchy (Layered Sequences)

```systemverilog
class apb_write_read_seq extends uvm_sequence #(apb_seq_item);
  `uvm_object_utils(apb_write_read_seq)

  function new(string name = "apb_write_read_seq");
    super.new(name);
  endfunction

  task body();
    apb_write_seq wr_seq = apb_write_seq::type_id::create("wr_seq");
    apb_read_seq  rd_seq = apb_read_seq::type_id::create("rd_seq");

    // Write first
    wr_seq.start(m_sequencer);

    // Then read back
    rd_seq.read_addr = 32'h0000_0010;
    rd_seq.start(m_sequencer);
  endtask
endclass
```

### 5.4 Sequence Macros: `uvm_do` Family

```systemverilog
task body();
  apb_seq_item req;

  // `uvm_do — create, randomize, and send
  `uvm_do(req)

  // `uvm_do_with — with inline constraints
  `uvm_do_with(req, { addr == 32'h100; write == 1; })

  // `uvm_do_on — on a specific sequencer
  `uvm_do_on(req, p_sequencer.sub_sqr)

  // `uvm_do_on_with — on specific sequencer with constraints
  `uvm_do_on_with(req, p_sequencer.sub_sqr, { write == 0; })
endtask
```

> **Best Practice**: Prefer `start_item` / `finish_item` over `uvm_do` macros for clarity and control. The macros hide important details and can make debugging harder.

---

## 6. UVM Phases

UVM uses a phased execution model. Phases ensure components are built and connected before execution begins.

### Phase Categories

| Category | Phases | Execution |
|----------|--------|-----------|
| **Build** | `build_phase` | Top-down |
| **Connect** | `connect_phase` | Bottom-up |
| **Elaboration** | `end_of_elaboration_phase` | Bottom-up |
| **Run-time** | `run_phase`, plus sub-phases | Parallel (task) |
| **Cleanup** | `extract_phase`, `check_phase`, `report_phase`, `final_phase` | Bottom-up |

### Phase Execution Order

```
1. build_phase          (top-down, function)
2. connect_phase        (bottom-up, function)
3. end_of_elaboration_phase (bottom-up, function)
4. start_of_simulation_phase (bottom-up, function)
5. run_phase            (parallel, task — all components run concurrently)
   ├── reset_phase
   ├── configure_phase
   ├── main_phase
   ├── shutdown_phase
   └── (custom phases possible)
6. extract_phase        (bottom-up, function)
7. check_phase          (bottom-up, function)
8. report_phase         (bottom-up, function)
9. final_phase          (bottom-up, function)
```

### Objections

The `run_phase` (and its sub-phases) uses objections to determine when to end:

```systemverilog
task run_phase(uvm_phase phase);
  phase.raise_objection(this, "Starting test stimulus");

  // Generate stimulus
  repeat(100) begin
    // ... drive transactions
  end

  phase.drop_objection(this, "Test stimulus complete");
endtask
```

> **Rule**: If no objections are raised in a phase, it ends immediately. Always raise an objection before time-consuming operations and drop it when done.

### Drain Time

You can set a drain time to allow in-flight transactions to complete after all objections are dropped:

```systemverilog
function void build_phase(uvm_phase phase);
  super.build_phase(phase);
  uvm_objection obj = phase.get_objection();
  obj.set_drain_time(this, 100ns);
endfunction
```

---

## 7. UVM Configuration Database

The `uvm_config_db` provides a way to pass configuration information between components without hard-coding dependencies.

### Setting Configuration

```systemverilog
// In the test or top module
// Syntax: uvm_config_db#(type)::set(context, instance_path, field_name, value)

// Pass a virtual interface
uvm_config_db#(virtual apb_if)::set(null, "uvm_test_top.env.agent.*", "vif", apb_vif);

// Pass a configuration object
apb_agent_config cfg = new();
cfg.is_active = UVM_ACTIVE;
cfg.has_coverage = 1;
uvm_config_db#(apb_agent_config)::set(this, "env.agent", "config", cfg);

// Pass a simple value
uvm_config_db#(int)::set(this, "env.agent", "num_transactions", 100);
```

### Getting Configuration

```systemverilog
// In the component
// Syntax: uvm_config_db#(type)::get(context, instance_path, field_name, variable)

function void build_phase(uvm_phase phase);
  super.build_phase(phase);

  if (!uvm_config_db#(virtual apb_if)::get(this, "", "vif", vif))
    `uvm_fatal("CFG_ERR", "Failed to get virtual interface")

  if (!uvm_config_db#(apb_agent_config)::get(this, "", "config", cfg))
    `uvm_fatal("CFG_ERR", "Failed to get agent configuration")
endfunction
```

### Configuration Object Pattern

Using dedicated configuration objects is a best practice:

```systemverilog
class apb_agent_config extends uvm_object;
  `uvm_object_utils(apb_agent_config)

  uvm_active_passive_enum is_active = UVM_ACTIVE;
  bit has_coverage = 1;
  bit has_checks   = 1;
  int num_transactions = 100;

  virtual apb_if vif;

  function new(string name = "apb_agent_config");
    super.new(name);
  endfunction
endclass
```

### Wildcards in Instance Paths

```systemverilog
// Apply to all agents
uvm_config_db#(int)::set(this, "env.agent*", "timeout", 1000);

// Apply to everything under env
uvm_config_db#(int)::set(this, "env.*", "verbose", 1);
```

---

## 8. UVM Factory

The factory is one of UVM's most powerful features. It enables type overrides without modifying existing code.

### Registration

All classes must be registered with the factory:

```systemverilog
// For uvm_object-derived classes
class my_transaction extends uvm_sequence_item;
  `uvm_object_utils(my_transaction)
  // ...
endclass

// For uvm_component-derived classes
class my_driver extends uvm_driver #(my_transaction);
  `uvm_component_utils(my_driver)
  // ...
endclass
```

### Creating Objects Through the Factory

Always use `type_id::create()` instead of `new()`:

```systemverilog
// Correct — uses factory
my_transaction tr = my_transaction::type_id::create("tr");
my_driver drv = my_driver::type_id::create("drv", this);

// Incorrect — bypasses factory, prevents overrides
my_transaction tr = new("tr");
```

### Type Overrides

Replace one type with another globally:

```systemverilog
class enhanced_driver extends apb_driver;
  `uvm_component_utils(enhanced_driver)
  // Extended functionality...
endclass

// In the test's build_phase:
function void build_phase(uvm_phase phase);
  super.build_phase(phase);

  // All future apb_driver creations will produce enhanced_driver instances
  apb_driver::type_id::set_type_override(enhanced_driver::get_type());

  // Alternative syntax
  set_type_override_by_type(apb_driver::get_type(), enhanced_driver::get_type());
endfunction
```

### Instance Overrides

Replace a type only at a specific location in the hierarchy:

```systemverilog
function void build_phase(uvm_phase phase);
  super.build_phase(phase);

  // Only override the driver in env.agent
  set_inst_override_by_type(
    "env.agent.drv",
    apb_driver::get_type(),
    enhanced_driver::get_type()
  );
endfunction
```

### Factory Override Example

```systemverilog
// Original transaction
class basic_packet extends uvm_sequence_item;
  `uvm_object_utils(basic_packet)
  rand bit [7:0] data;

  function new(string name = "basic_packet");
    super.new(name);
  endfunction
endclass

// Extended transaction with error injection
class error_packet extends basic_packet;
  `uvm_object_utils(error_packet)
  rand bit inject_error;
  rand bit [3:0] error_type;

  constraint error_rate_c { inject_error dist { 0 := 90, 1 := 10 }; }

  function new(string name = "error_packet");
    super.new(name);
  endfunction
endclass

// In the test — no changes to agent, driver, or sequences needed
class error_injection_test extends apb_base_test;
  `uvm_component_utils(error_injection_test)

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    basic_packet::type_id::set_type_override(error_packet::get_type());
  endfunction
endclass
```

---

## 9. TLM (Transaction Level Modeling)

TLM provides standardized communication between components using ports and exports.

### 9.1 Analysis Ports (One-to-Many, Non-Blocking)

The most common TLM connection in UVM:

```systemverilog
// Producer (e.g., Monitor)
class my_monitor extends uvm_monitor;
  uvm_analysis_port #(my_transaction) ap;

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ap = new("ap", this);
  endfunction

  task run_phase(uvm_phase phase);
    forever begin
      my_transaction tr = my_transaction::type_id::create("tr");
      // ... collect transaction from interface
      ap.write(tr);  // Broadcast to all connected subscribers
    end
  endtask
endclass

// Consumer (e.g., Scoreboard)
class my_scoreboard extends uvm_scoreboard;
  uvm_analysis_imp #(my_transaction, my_scoreboard) analysis_export;

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    analysis_export = new("analysis_export", this);
  endfunction

  function void write(my_transaction tr);
    // Process the transaction
    `uvm_info("SCB", tr.convert2string(), UVM_MEDIUM)
  endfunction
endclass
```

### 9.2 Analysis FIFOs

When the subscriber needs to process transactions asynchronously:

```systemverilog
class my_scoreboard extends uvm_scoreboard;
  uvm_tlm_analysis_fifo #(my_transaction) expected_fifo;
  uvm_tlm_analysis_fifo #(my_transaction) actual_fifo;

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    expected_fifo = new("expected_fifo", this);
    actual_fifo   = new("actual_fifo", this);
  endfunction

  task run_phase(uvm_phase phase);
    my_transaction expected_tr, actual_tr;
    forever begin
      expected_fifo.get(expected_tr);
      actual_fifo.get(actual_tr);
      if (!expected_tr.compare(actual_tr))
        `uvm_error("MISMATCH", "Expected and actual transactions differ")
    end
  endtask
endclass
```

### 9.3 Multiple Analysis Ports with `uvm_analysis_imp_decl`

When a component needs to receive from multiple analysis ports:

```systemverilog
`uvm_analysis_imp_decl(_expected)
`uvm_analysis_imp_decl(_actual)

class dual_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(dual_scoreboard)

  uvm_analysis_imp_expected #(my_transaction, dual_scoreboard) expected_export;
  uvm_analysis_imp_actual   #(my_transaction, dual_scoreboard) actual_export;

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    expected_export = new("expected_export", this);
    actual_export   = new("actual_export", this);
  endfunction

  function void write_expected(my_transaction tr);
    // Handle expected transaction
  endfunction

  function void write_actual(my_transaction tr);
    // Handle actual transaction
  endfunction
endclass
```

### 9.4 Blocking Put/Get Ports

For point-to-point communication:

```systemverilog
// Producer
class producer extends uvm_component;
  uvm_blocking_put_port #(my_transaction) put_port;

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    put_port = new("put_port", this);
  endfunction

  task run_phase(uvm_phase phase);
    my_transaction tr = new("tr");
    put_port.put(tr);
  endtask
endclass

// Consumer
class consumer extends uvm_component;
  uvm_blocking_put_imp #(my_transaction, consumer) put_export;

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    put_export = new("put_export", this);
  endfunction

  task put(my_transaction tr);
    // Process the transaction
  endtask
endclass
```

---

## 10. UVM Reporting and Messaging

### Severity Levels

```systemverilog
`uvm_info   ("TAG", "Informational message",    UVM_MEDIUM)
`uvm_warning("TAG", "Warning message")
`uvm_error  ("TAG", "Error — test may continue")
`uvm_fatal  ("TAG", "Fatal — simulation stops immediately")
```

### Verbosity Levels

```
UVM_NONE   = 0    // Always printed
UVM_LOW    = 100  // Important messages
UVM_MEDIUM = 200  // Standard messages (default threshold)
UVM_HIGH   = 300  // Detailed messages
UVM_FULL   = 400  // Very detailed
UVM_DEBUG  = 500  // Debug-level detail
```

### Controlling Verbosity

```systemverilog
// Set verbosity for the entire testbench
uvm_top.set_report_verbosity_level(UVM_HIGH);

// Set verbosity for a specific component
env.agent.mon.set_report_verbosity_level(UVM_DEBUG);

// From the command line
// +UVM_VERBOSITY=UVM_HIGH
// +uvm_set_verbosity=uvm_test_top.env.agent.mon,MON,UVM_DEBUG,run
```

### Report Servers and Custom Actions

```systemverilog
// Change the action for a specific message ID
set_report_severity_action(UVM_ERROR, UVM_DISPLAY | UVM_COUNT);

// Set maximum number of errors before stopping
set_report_max_quit_count(10);

// Override severity for specific ID
set_report_severity_id_override(UVM_WARNING, "TIMEOUT", UVM_ERROR);
```

---

## 11. UVM Register Abstraction Layer (RAL)

The RAL provides a high-level abstraction for accessing DUT registers.

### 11.1 Register Model Definition

```systemverilog
// Individual register
class ctrl_reg extends uvm_reg;
  `uvm_object_utils(ctrl_reg)

  rand uvm_reg_field enable;
  rand uvm_reg_field mode;
  rand uvm_reg_field status;

  function new(string name = "ctrl_reg");
    super.new(name, 32, UVM_NO_COVERAGE);
  endfunction

  virtual function void build();
    enable = uvm_reg_field::type_id::create("enable");
    enable.configure(this, 1, 0, "RW", 0, 1'b0, 1, 1, 0);
    //                     bits, lsb, access, volatile, reset, has_reset, is_rand, individually_accessible

    mode = uvm_reg_field::type_id::create("mode");
    mode.configure(this, 2, 1, "RW", 0, 2'b00, 1, 1, 0);

    status = uvm_reg_field::type_id::create("status");
    status.configure(this, 4, 4, "RO", 1, 4'b0000, 1, 0, 0);
  endfunction
endclass

// Register block
class my_reg_block extends uvm_reg_block;
  `uvm_object_utils(my_reg_block)

  rand ctrl_reg  ctrl;
  rand uvm_reg   data_reg;

  uvm_reg_map    default_map;

  function new(string name = "my_reg_block");
    super.new(name, UVM_NO_COVERAGE);
  endfunction

  virtual function void build();
    ctrl = ctrl_reg::type_id::create("ctrl");
    ctrl.configure(this);
    ctrl.build();

    default_map = create_map("default_map", 0, 4, UVM_LITTLE_ENDIAN);
    default_map.add_reg(ctrl, 'h00, "RW");
  endfunction
endclass
```

### 11.2 Register Adapter

Translates between register operations and bus transactions:

```systemverilog
class apb_reg_adapter extends uvm_reg_adapter;
  `uvm_object_utils(apb_reg_adapter)

  function new(string name = "apb_reg_adapter");
    super.new(name);
    supports_byte_enable = 0;
    provides_responses   = 0;
  endfunction

  virtual function uvm_sequence_item reg2bus(const ref uvm_reg_bus_op rw);
    apb_seq_item tr = apb_seq_item::type_id::create("tr");
    tr.addr  = rw.addr;
    tr.write = (rw.kind == UVM_WRITE);
    tr.data  = rw.data;
    return tr;
  endfunction

  virtual function void bus2reg(uvm_sequence_item bus_item, ref uvm_reg_bus_op rw);
    apb_seq_item tr;
    if (!$cast(tr, bus_item))
      `uvm_fatal("CAST_FAIL", "Failed to cast bus_item to apb_seq_item")

    rw.addr   = tr.addr;
    rw.kind   = tr.write ? UVM_WRITE : UVM_READ;
    rw.data   = tr.write ? tr.data : tr.rdata;
    rw.status = UVM_IS_OK;
  endfunction
endclass
```

### 11.3 Using the Register Model

```systemverilog
class reg_test extends apb_base_test;
  `uvm_component_utils(reg_test)

  my_reg_block reg_model;

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    reg_model = my_reg_block::type_id::create("reg_model");
    reg_model.build();
    reg_model.lock_model();
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    apb_reg_adapter adapter = new("adapter");
    reg_model.default_map.set_sequencer(env.agent.sqr, adapter);
    reg_model.default_map.set_auto_predict(1);
  endfunction

  task run_phase(uvm_phase phase);
    uvm_status_e status;
    uvm_reg_data_t rdata;

    phase.raise_objection(this);

    // Write to register
    reg_model.ctrl.write(status, 32'h0000_0005);

    // Read from register
    reg_model.ctrl.read(status, rdata);
    `uvm_info("REG", $sformatf("CTRL = 0x%08h", rdata), UVM_LOW)

    // Access individual fields
    reg_model.ctrl.enable.set(1);
    reg_model.ctrl.mode.set(2'b11);
    reg_model.ctrl.update(status);

    // Mirror (read from DUT and update model)
    reg_model.ctrl.mirror(status, UVM_CHECK);

    phase.drop_objection(this);
  endtask
endclass
```

### 11.4 Built-in Register Test Sequences

```systemverilog
// Hardware reset test
uvm_reg_hw_reset_seq rst_seq = uvm_reg_hw_reset_seq::type_id::create("rst_seq");
rst_seq.model = reg_model;
rst_seq.start(env.agent.sqr);

// Bit-bash test (write/read all bits)
uvm_reg_bit_bash_seq bb_seq = uvm_reg_bit_bash_seq::type_id::create("bb_seq");
bb_seq.model = reg_model;
bb_seq.start(env.agent.sqr);
```

---

## 12. Advanced: Callbacks

Callbacks allow injecting custom behavior into existing components without modifying them.

### Defining a Callback

```systemverilog
// Callback base class
class apb_driver_cb extends uvm_callback;
  `uvm_object_utils(apb_driver_cb)

  function new(string name = "apb_driver_cb");
    super.new(name);
  endfunction

  virtual task pre_drive(apb_driver drv, apb_seq_item tr);
  endtask

  virtual task post_drive(apb_driver drv, apb_seq_item tr);
  endtask
endclass

// Register the callback type with the driver
typedef uvm_callbacks #(apb_driver, apb_driver_cb) apb_driver_cb_t;

// Modify the driver to invoke callbacks
class apb_driver extends uvm_driver #(apb_seq_item);
  `uvm_component_utils(apb_driver)
  `uvm_register_cb(apb_driver, apb_driver_cb)

  task run_phase(uvm_phase phase);
    forever begin
      seq_item_port.get_next_item(req);
      `uvm_do_callbacks(apb_driver, apb_driver_cb, pre_drive(this, req))
      drive_transaction(req);
      `uvm_do_callbacks(apb_driver, apb_driver_cb, post_drive(this, req))
      seq_item_port.item_done();
    end
  endtask
endclass
```

### Using a Callback

```systemverilog
class error_injection_cb extends apb_driver_cb;
  `uvm_object_utils(error_injection_cb)

  function new(string name = "error_injection_cb");
    super.new(name);
  endfunction

  virtual task pre_drive(apb_driver drv, apb_seq_item tr);
    if ($urandom_range(0, 99) < 5) begin
      tr.data = ~tr.data;  // Corrupt data 5% of the time
      `uvm_info("ERR_CB", "Injected data corruption", UVM_LOW)
    end
  endtask
endclass

// In the test
class error_test extends apb_base_test;
  `uvm_component_utils(error_test)

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    error_injection_cb cb = new("err_cb");
    uvm_callbacks #(apb_driver, apb_driver_cb)::add(env.agent.drv, cb);
  endfunction
endclass
```

---

## 13. Advanced: Virtual Sequences and Virtual Sequencers

Virtual sequences coordinate stimulus across multiple agents/interfaces.

### Virtual Sequencer

```systemverilog
class system_virtual_sequencer extends uvm_sequencer;
  `uvm_component_utils(system_virtual_sequencer)

  apb_sequencer  apb_sqr;
  axi_sequencer  axi_sqr;
  spi_sequencer  spi_sqr;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
endclass
```

### Virtual Sequence

```systemverilog
class system_init_vseq extends uvm_sequence;
  `uvm_object_utils(system_init_vseq)
  `uvm_declare_p_sequencer(system_virtual_sequencer)

  function new(string name = "system_init_vseq");
    super.new(name);
  endfunction

  task body();
    apb_write_seq    apb_seq = apb_write_seq::type_id::create("apb_seq");
    axi_burst_seq    axi_seq = axi_burst_seq::type_id::create("axi_seq");

    // Configure the DUT via APB first
    apb_seq.start(p_sequencer.apb_sqr);

    // Then initiate data transfer via AXI
    fork
      axi_seq.start(p_sequencer.axi_sqr);
      begin
        #100ns;
        spi_read_seq spi_seq = spi_read_seq::type_id::create("spi_seq");
        spi_seq.start(p_sequencer.spi_sqr);
      end
    join
  endtask
endclass
```

### Connecting in the Environment

```systemverilog
class system_env extends uvm_env;
  `uvm_component_utils(system_env)

  apb_agent                 apb_agt;
  axi_agent                 axi_agt;
  spi_agent                 spi_agt;
  system_virtual_sequencer  v_sqr;

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    v_sqr.apb_sqr = apb_agt.sqr;
    v_sqr.axi_sqr = axi_agt.sqr;
    v_sqr.spi_sqr = spi_agt.sqr;
  endfunction
endclass
```

---

## 14. Advanced: Coverage-Driven Verification

### Functional Coverage Collector

```systemverilog
class apb_coverage extends uvm_subscriber #(apb_seq_item);
  `uvm_component_utils(apb_coverage)

  apb_seq_item tr;

  covergroup apb_cg;
    addr_cp: coverpoint tr.addr {
      bins low_range   = {[32'h0000:32'h00FF]};
      bins mid_range   = {[32'h0100:32'h0FFF]};
      bins high_range  = {[32'h1000:32'hFFFF]};
    }

    write_cp: coverpoint tr.write {
      bins read  = {0};
      bins write = {1};
    }

    data_cp: coverpoint tr.data {
      bins zero     = {0};
      bins small    = {[1:255]};
      bins medium   = {[256:65535]};
      bins large    = {[65536:$]};
      bins all_ones = {32'hFFFF_FFFF};
    }

    addr_x_write: cross addr_cp, write_cp;
  endgroup

  function new(string name, uvm_component parent);
    super.new(name, parent);
    apb_cg = new();
  endfunction

  function void write(apb_seq_item t);
    tr = t;
    apb_cg.sample();
  endfunction

  function void report_phase(uvm_phase phase);
    `uvm_info("COV", $sformatf("APB Coverage: %.2f%%",
              apb_cg.get_coverage()), UVM_LOW)
  endfunction
endclass
```

### Coverage-Driven Test Closure

```systemverilog
class coverage_driven_test extends apb_base_test;
  `uvm_component_utils(coverage_driven_test)

  task run_phase(uvm_phase phase);
    apb_write_read_seq seq;
    phase.raise_objection(this);

    // Run until coverage target is met or max iterations reached
    for (int i = 0; i < 10000 && env.coverage.apb_cg.get_coverage() < 95.0; i++) begin
      seq = apb_write_read_seq::type_id::create("seq");
      seq.start(env.agent.sqr);
    end

    `uvm_info("TEST", $sformatf("Final coverage: %.2f%%",
              env.coverage.apb_cg.get_coverage()), UVM_LOW)
    phase.drop_objection(this);
  endtask
endclass
```

---

## 15. Advanced: Scoreboards and Checkers

### In-Order Scoreboard

```systemverilog
class apb_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(apb_scoreboard)

  uvm_analysis_imp #(apb_seq_item, apb_scoreboard) analysis_export;

  bit [31:0] memory [bit [31:0]];
  int pass_count, fail_count;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    analysis_export = new("analysis_export", this);
  endfunction

  function void write(apb_seq_item tr);
    if (tr.write) begin
      memory[tr.addr] = tr.data;
      `uvm_info("SCB", $sformatf("WRITE: addr=0x%08h data=0x%08h", tr.addr, tr.data), UVM_HIGH)
    end else begin
      if (memory.exists(tr.addr)) begin
        if (tr.rdata == memory[tr.addr]) begin
          pass_count++;
          `uvm_info("SCB", $sformatf("PASS: addr=0x%08h expected=0x%08h got=0x%08h",
                    tr.addr, memory[tr.addr], tr.rdata), UVM_MEDIUM)
        end else begin
          fail_count++;
          `uvm_error("SCB", $sformatf("FAIL: addr=0x%08h expected=0x%08h got=0x%08h",
                     tr.addr, memory[tr.addr], tr.rdata))
        end
      end else begin
        `uvm_warning("SCB", $sformatf("READ from uninitialized addr=0x%08h", tr.addr))
      end
    end
  endfunction

  function void report_phase(uvm_phase phase);
    `uvm_info("SCB", $sformatf("Scoreboard Results: %0d PASS, %0d FAIL",
              pass_count, fail_count), UVM_LOW)
    if (fail_count > 0)
      `uvm_error("SCB", "TEST FAILED — mismatches detected")
    else
      `uvm_info("SCB", "TEST PASSED", UVM_NONE)
  endfunction
endclass
```

### Out-of-Order Scoreboard

```systemverilog
class ooo_scoreboard #(type T = uvm_sequence_item) extends uvm_scoreboard;

  uvm_tlm_analysis_fifo #(T) expected_fifo;
  uvm_tlm_analysis_fifo #(T) actual_fifo;

  T expected_queue[$];

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    expected_fifo = new("expected_fifo", this);
    actual_fifo   = new("actual_fifo", this);
  endfunction

  task run_phase(uvm_phase phase);
    T expected_tr, actual_tr;
    fork
      forever begin
        expected_fifo.get(expected_tr);
        expected_queue.push_back(expected_tr);
      end

      forever begin
        actual_fifo.get(actual_tr);
        check_and_remove(actual_tr);
      end
    join
  endtask

  function void check_and_remove(T actual);
    foreach (expected_queue[i]) begin
      if (expected_queue[i].compare(actual)) begin
        expected_queue.delete(i);
        `uvm_info("OOO_SCB", "Match found", UVM_HIGH)
        return;
      end
    end
    `uvm_error("OOO_SCB", "No matching expected transaction found")
  endfunction
endclass
```

---

## 16. Practical Examples

Complete practical examples are provided as separate files in the `examples/` directory:

| Example | Directory | Description |
|---------|-----------|-------------|
| **APB Slave Verification** | [`examples/01_apb_slave/`](../examples/01_apb_slave/) | Complete UVM testbench for an APB slave memory device |
| **FIFO Verification** | [`examples/02_fifo/`](../examples/02_fifo/) | Verifying a synchronous FIFO with coverage and scoreboard |
| **ALU Verification** | [`examples/03_alu/`](../examples/03_alu/) | Arithmetic Logic Unit verification with constrained random testing |

See each example directory for full source code and detailed comments.

---

## 17. Common Pitfalls and Best Practices

### Pitfalls to Avoid

1. **Forgetting `super.build_phase(phase)`**: Always call the parent's phase method first.

2. **Using `new()` instead of `type_id::create()`**: Bypasses the factory and prevents overrides.

3. **Missing objections**: If `run_phase` raises no objection, it ends at time 0.

4. **Config DB path errors**: Paths are relative to the component calling `set()`. A common mistake:
   ```systemverilog
   // Wrong: path doesn't match component hierarchy
   uvm_config_db#(int)::set(null, "agent", "timeout", 100);
   // Correct: use full path from uvm_test_top
   uvm_config_db#(int)::set(null, "uvm_test_top.env.agent", "timeout", 100);
   ```

5. **Connecting ports incorrectly**: Port directions matter — connect `port` to `export` or `imp`, not the reverse.

6. **Not locking the register model**: Always call `lock_model()` after building the register block.

### Best Practices

1. **Use configuration objects** instead of individual `config_db` entries for cleaner parameterization.

2. **Create a base test** with common setup; derive specific tests from it.

3. **Keep sequences reusable**: Don't hard-code addresses or data — use class fields or configuration.

4. **Use analysis ports** for monitor-to-scoreboard/coverage connections (one-to-many, non-blocking).

5. **Implement `convert2string()`** on all transaction classes for readable debug output.

6. **Set appropriate verbosity levels**: Use `UVM_LOW` for critical info, `UVM_HIGH` for debug.

7. **Use the factory consistently**: Register every class, create through factory, override in tests.

8. **Write self-checking tests**: Always verify outputs with a scoreboard, not just by visual inspection.

9. **Separate concerns**: One agent per interface, one scoreboard per protocol, one coverage collector per feature.

10. **Use `uvm_fatal` sparingly**: Reserve it for truly unrecoverable situations (missing config, cast failures).

---

## Quick Reference

### Essential Macros

| Macro | Purpose |
|-------|---------|
| `` `uvm_component_utils(T) `` | Register a component class with the factory |
| `` `uvm_object_utils(T) `` | Register an object class with the factory |
| `` `uvm_info(ID, MSG, VERB) `` | Log an informational message |
| `` `uvm_warning(ID, MSG) `` | Log a warning |
| `` `uvm_error(ID, MSG) `` | Log an error |
| `` `uvm_fatal(ID, MSG) `` | Log a fatal error and stop simulation |
| `` `uvm_do(SEQ_OR_ITEM) `` | Create, randomize, and execute a sequence item |
| `` `uvm_do_with(SEQ_OR_ITEM, CONSTRAINTS) `` | Same as above with inline constraints |
| `` `uvm_declare_p_sequencer(SQRTYPE) `` | Declare typed sequencer handle in a sequence |

### Common Command-Line Arguments

```bash
# Run a specific test
+UVM_TESTNAME=apb_write_test

# Set verbosity
+UVM_VERBOSITY=UVM_HIGH

# Set timeout
+UVM_TIMEOUT=1000000

# Print topology
+UVM_PRINT_TOPOLOGY

# Enable config_db tracing
+UVM_CONFIG_DB_TRACE

# Factory override from command line
+uvm_set_type_override=apb_driver,enhanced_driver
```

---

*This tutorial is part of a series of verification resources. For complete runnable examples, see the `examples/` directory.*
