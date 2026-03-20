# 1. UVM Basics — Introduction, Class Hierarchy, and Core Components

[&larr; Back to Main](../README.md) | [Next: Phases & Lifecycle &rarr;](02_uvm_phases.md)

---

## 1.1 What is UVM?

UVM (Universal Verification Methodology) is a **SystemVerilog class library** and a set of conventions for building verification environments. It provides:

- A base class hierarchy for testbench components
- A phasing mechanism to control simulation flow
- A factory for object creation and overrides
- A configuration database for passing settings between components
- Transaction-Level Modeling (TLM) ports for inter-component communication
- Built-in reporting and messaging

All UVM classes inherit from `uvm_void` at the very top, but the two practical roots are:

| Root Class | Purpose |
|------------|---------|
| `uvm_object` | Data objects (transactions, sequence items, configurations) |
| `uvm_component` | Structural testbench components (drivers, monitors, agents) |

---

## 1.2 The UVM Class Hierarchy

```
uvm_void
├── uvm_object
│   ├── uvm_transaction
│   │   └── uvm_sequence_item        ← stimulus transactions
│   ├── uvm_sequence                  ← stimulus generators
│   ├── uvm_reg_block                 ← register model
│   └── uvm_report_object
│       └── uvm_component
│           ├── uvm_monitor           ← passive observer
│           ├── uvm_driver            ← drives DUT pins
│           ├── uvm_sequencer         ← arbitrates sequences
│           ├── uvm_agent             ← groups driver+monitor+sequencer
│           ├── uvm_env               ← top-level testbench container
│           ├── uvm_test              ← test scenario
│           ├── uvm_scoreboard        ← checking logic
│           └── uvm_subscriber        ← coverage collector
```

### Key Distinction: `uvm_object` vs `uvm_component`

| Property | `uvm_object` | `uvm_component` |
|----------|-------------|-----------------|
| Lifetime | Transient — created and destroyed during simulation | Persistent — exists for the entire simulation |
| Hierarchy | None | Parent-child tree |
| Phases | Not phased | Participates in UVM phases |
| Factory registration | `uvm_object_utils` | `uvm_component_utils` |
| Typical use | Transactions, config objects | Driver, monitor, agent, env |

---

## 1.3 Core Components in Detail

### 1.3.1 `uvm_sequence_item` — The Transaction

A transaction represents a single unit of stimulus or response. Think of it as the data that flows through your testbench.

```systemverilog
class alu_transaction extends uvm_sequence_item;

  // Declare fields
  rand bit [7:0]  operand_a;
  rand bit [7:0]  operand_b;
  rand bit [1:0]  operation;  // 0=ADD, 1=SUB, 2=AND, 3=OR
       bit [8:0]  result;

  // Register with factory
  `uvm_object_utils_begin(alu_transaction)
    `uvm_field_int(operand_a, UVM_ALL_ON)
    `uvm_field_int(operand_b, UVM_ALL_ON)
    `uvm_field_int(operation, UVM_ALL_ON)
    `uvm_field_int(result,    UVM_ALL_ON)
  `uvm_object_utils_end

  // Constructor
  function new(string name = "alu_transaction");
    super.new(name);
  endfunction

  // Optional: constraints for randomization
  constraint valid_ops {
    operation inside {[0:3]};
  }

endclass
```

**Key points:**

- Fields marked `rand` are randomized when `sequence.randomize()` is called.
- The field macros (`uvm_field_int`, `uvm_field_string`, etc.) auto-generate `copy()`, `compare()`, `print()`, `pack()`, and `unpack()` methods.
- The constructor **must** call `super.new(name)`.

### 1.3.2 `uvm_driver` — Pin-Level Stimulus

The driver receives transactions from the sequencer and converts them into pin-level activity on the DUT interface.

```systemverilog
class alu_driver extends uvm_driver #(alu_transaction);

  `uvm_component_utils(alu_driver)

  virtual alu_if vif;  // virtual interface handle

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual alu_if)::get(this, "", "alu_vif", vif))
      `uvm_fatal("NO_VIF", "Virtual interface not found in config_db")
  endfunction

  virtual task run_phase(uvm_phase phase);
    alu_transaction txn;
    forever begin
      // Get next transaction from sequencer
      seq_item_port.get_next_item(txn);

      // Drive signals on DUT interface
      @(posedge vif.clk);
      vif.operand_a <= txn.operand_a;
      vif.operand_b <= txn.operand_b;
      vif.operation <= txn.operation;
      vif.valid     <= 1'b1;

      @(posedge vif.clk);
      vif.valid     <= 1'b0;

      // Signal sequencer that we are done
      seq_item_port.item_done();
    end
  endtask

endclass
```

**Key points:**

- Parameterized with the transaction type: `uvm_driver #(alu_transaction)`.
- Uses `seq_item_port.get_next_item()` / `item_done()` handshake with the sequencer.
- Gets the virtual interface from `uvm_config_db` during `build_phase`.

### 1.3.3 `uvm_monitor` — Passive Observer

The monitor observes DUT signals **without driving them** and converts observed pin activity back into transactions for analysis.

```systemverilog
class alu_monitor extends uvm_monitor;

  `uvm_component_utils(alu_monitor)

  virtual alu_if vif;

  // Analysis port to broadcast observed transactions
  uvm_analysis_port #(alu_transaction) ap;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ap = new("ap", this);
    if (!uvm_config_db#(virtual alu_if)::get(this, "", "alu_vif", vif))
      `uvm_fatal("NO_VIF", "Virtual interface not found in config_db")
  endfunction

  virtual task run_phase(uvm_phase phase);
    alu_transaction txn;
    forever begin
      @(posedge vif.clk);
      if (vif.valid) begin
        txn = alu_transaction::type_id::create("txn");
        txn.operand_a = vif.operand_a;
        txn.operand_b = vif.operand_b;
        txn.operation = vif.operation;

        // Wait for result
        @(posedge vif.clk);
        txn.result = vif.result;

        // Broadcast to all subscribers
        ap.write(txn);
        `uvm_info("MON", $sformatf("Observed: a=%0d b=%0d op=%0d result=%0d",
                  txn.operand_a, txn.operand_b, txn.operation, txn.result), UVM_MEDIUM)
      end
    end
  endtask

endclass
```

**Key points:**

- The `uvm_analysis_port` broadcasts transactions using a publish-subscribe pattern.
- Multiple subscribers (scoreboard, coverage collector) can connect to the same analysis port.
- Monitors should **never** drive DUT signals.

### 1.3.4 `uvm_sequencer` — Transaction Arbiter

The sequencer routes transactions from sequences to the driver. In most cases you use the default parameterized sequencer without extending it.

```systemverilog
typedef uvm_sequencer #(alu_transaction) alu_sequencer;
```

If you need custom arbitration, you can extend it:

```systemverilog
class alu_sequencer extends uvm_sequencer #(alu_transaction);

  `uvm_component_utils(alu_sequencer)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

endclass
```

### 1.3.5 `uvm_agent` — Component Group

An agent bundles a driver, monitor, and sequencer together. The `is_active` flag controls whether the agent drives stimulus (active) or only monitors (passive).

```systemverilog
class alu_agent extends uvm_agent;

  `uvm_component_utils(alu_agent)

  alu_driver    drv;
  alu_monitor   mon;
  alu_sequencer sqr;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Monitor is always present
    mon = alu_monitor::type_id::create("mon", this);

    // Driver and sequencer only in active mode
    if (get_is_active() == UVM_ACTIVE) begin
      drv = alu_driver::type_id::create("drv", this);
      sqr = alu_sequencer::type_id::create("sqr", this);
    end
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    if (get_is_active() == UVM_ACTIVE) begin
      drv.seq_item_port.connect(sqr.seq_item_export);
    end
  endfunction

endclass
```

**Key points:**

- Use `get_is_active()` to check whether the agent should be active or passive.
- In `connect_phase`, the driver's `seq_item_port` is connected to the sequencer's `seq_item_export`.
- Factory creation (`type_id::create`) enables runtime type overrides.

### 1.3.6 `uvm_env` — Testbench Container

The environment instantiates agents, scoreboards, and coverage collectors.

```systemverilog
class alu_env extends uvm_env;

  `uvm_component_utils(alu_env)

  alu_agent      agt;
  alu_scoreboard sb;
  alu_coverage   cov;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    agt = alu_agent::type_id::create("agt", this);
    sb  = alu_scoreboard::type_id::create("sb", this);
    cov = alu_coverage::type_id::create("cov", this);
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    // Connect monitor's analysis port to scoreboard and coverage
    agt.mon.ap.connect(sb.analysis_export);
    agt.mon.ap.connect(cov.analysis_export);
  endfunction

endclass
```

### 1.3.7 `uvm_test` — Test Scenario

Each test class defines a specific test scenario. It creates the environment and starts sequences.

```systemverilog
class alu_base_test extends uvm_test;

  `uvm_component_utils(alu_base_test)

  alu_env env;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = alu_env::type_id::create("env", this);
  endfunction

  virtual task run_phase(uvm_phase phase);
    alu_base_sequence seq;

    phase.raise_objection(this);

    seq = alu_base_sequence::type_id::create("seq");
    seq.start(env.agt.sqr);

    phase.drop_objection(this);
  endtask

  virtual function void report_phase(uvm_phase phase);
    uvm_report_server srv = uvm_report_server::get_server();
    if (srv.get_severity_count(UVM_ERROR) > 0)
      `uvm_info("TEST", "*** TEST FAILED ***", UVM_NONE)
    else
      `uvm_info("TEST", "*** TEST PASSED ***", UVM_NONE)
  endfunction

endclass
```

### 1.3.8 `uvm_scoreboard` — Checker

The scoreboard compares expected outputs with actual DUT outputs.

```systemverilog
class alu_scoreboard extends uvm_scoreboard;

  `uvm_component_utils(alu_scoreboard)

  uvm_analysis_imp #(alu_transaction, alu_scoreboard) analysis_export;

  int pass_count = 0;
  int fail_count = 0;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    analysis_export = new("analysis_export", this);
  endfunction

  // Called automatically when monitor writes a transaction
  virtual function void write(alu_transaction txn);
    bit [8:0] expected;

    case (txn.operation)
      2'b00: expected = txn.operand_a + txn.operand_b;
      2'b01: expected = txn.operand_a - txn.operand_b;
      2'b10: expected = txn.operand_a & txn.operand_b;
      2'b11: expected = txn.operand_a | txn.operand_b;
    endcase

    if (expected == txn.result) begin
      pass_count++;
      `uvm_info("SB", $sformatf("PASS: a=%0d b=%0d op=%0d expected=%0d got=%0d",
                txn.operand_a, txn.operand_b, txn.operation, expected, txn.result), UVM_HIGH)
    end else begin
      fail_count++;
      `uvm_error("SB", $sformatf("FAIL: a=%0d b=%0d op=%0d expected=%0d got=%0d",
                 txn.operand_a, txn.operand_b, txn.operation, expected, txn.result))
    end
  endfunction

  virtual function void report_phase(uvm_phase phase);
    `uvm_info("SB", $sformatf("Scoreboard: %0d passed, %0d failed out of %0d total",
              pass_count, fail_count, pass_count + fail_count), UVM_NONE)
  endfunction

endclass
```

---

## 1.4 The Interface and Top-Level Module

### SystemVerilog Interface

```systemverilog
interface alu_if(input logic clk, input logic rst_n);
  logic [7:0] operand_a;
  logic [7:0] operand_b;
  logic [1:0] operation;
  logic       valid;
  logic [8:0] result;
  logic       result_valid;
endinterface
```

### Top-Level Testbench Module

```systemverilog
module tb_top;
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  // Clock and reset
  bit clk;
  bit rst_n;

  always #5 clk = ~clk;  // 100 MHz clock

  initial begin
    rst_n = 0;
    #20 rst_n = 1;
  end

  // Interface instance
  alu_if aif(clk, rst_n);

  // DUT instantiation
  alu dut (
    .clk       (clk),
    .rst_n     (rst_n),
    .operand_a (aif.operand_a),
    .operand_b (aif.operand_b),
    .operation (aif.operation),
    .valid     (aif.valid),
    .result    (aif.result),
    .result_valid(aif.result_valid)
  );

  // Pass virtual interface to UVM via config_db
  initial begin
    uvm_config_db#(virtual alu_if)::set(null, "*", "alu_vif", aif);
    run_test();  // test name from +UVM_TESTNAME=... on command line
  end

  // Optional: dump waveforms
  initial begin
    $dumpfile("dump.vcd");
    $dumpvars(0, tb_top);
  end

endmodule
```

**Key points:**

- `uvm_config_db#(virtual alu_if)::set(null, "*", "alu_vif", aif)` stores the interface handle so all components can retrieve it.
- `run_test()` starts UVM — it looks up the test name from the command line argument `+UVM_TESTNAME=alu_base_test`.
- The top module is the **only** place where `module`-level (non-class) code exists.

---

## 1.5 UVM Macros Quick Reference

| Macro | Purpose |
|-------|---------|
| `` `uvm_component_utils(T) `` | Register component class `T` with the factory |
| `` `uvm_object_utils(T) `` | Register data object class `T` with the factory |
| `` `uvm_field_int(F, FLAGS) `` | Auto-implement copy/compare/print for integer field `F` |
| `` `uvm_field_string(F, FLAGS) `` | Same for string field |
| `` `uvm_field_object(F, FLAGS) `` | Same for object field |
| `` `uvm_field_enum(T, F, FLAGS) `` | Same for enum field of type `T` |
| `` `uvm_info(ID, MSG, VERB) `` | Print informational message |
| `` `uvm_warning(ID, MSG) `` | Print warning |
| `` `uvm_error(ID, MSG) `` | Print error (simulation continues) |
| `` `uvm_fatal(ID, MSG) `` | Print fatal error (simulation stops) |

### Verbosity Levels

| Level | Value | When to use |
|-------|-------|-------------|
| `UVM_NONE` | 0 | Always printed |
| `UVM_LOW` | 100 | Important milestones |
| `UVM_MEDIUM` | 200 | General information (default threshold) |
| `UVM_HIGH` | 300 | Detailed debug info |
| `UVM_FULL` | 400 | Very detailed debug info |
| `UVM_DEBUG` | 500 | Maximum detail |

Set verbosity from the command line: `+UVM_VERBOSITY=UVM_HIGH`

---

## 1.6 Summary

| Concept | Key Takeaway |
|---------|-------------|
| `uvm_sequence_item` | Data container for stimulus/response |
| `uvm_driver` | Converts transactions to pin-level signals |
| `uvm_monitor` | Observes pins, creates transactions, broadcasts via analysis port |
| `uvm_sequencer` | Arbitrates between sequences, feeds driver |
| `uvm_agent` | Groups driver + monitor + sequencer |
| `uvm_env` | Top-level container for agents, scoreboards, coverage |
| `uvm_test` | Defines one test scenario; creates env, starts sequences |
| `uvm_scoreboard` | Compares DUT output against expected values |

---

[Next: UVM Phases & Lifecycle &rarr;](02_uvm_phases.md)
