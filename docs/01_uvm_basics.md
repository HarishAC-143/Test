# Chapter 1 -- UVM Basics

## 1.1 What is UVM?

The **Universal Verification Methodology (UVM)** is an industry-standard, open-source
SystemVerilog class library and set of coding guidelines for building reusable, scalable
verification environments. It was standardized by **Accellera** and adopted as **IEEE
1800.2-2017**.

UVM solves several problems that plague ad-hoc verification:

| Problem | UVM Solution |
|---------|-------------|
| Code reuse across projects | Component-based architecture with standardized interfaces |
| Stimulus portability | Sequence mechanism decouples stimulus from structure |
| Configuration flexibility | Configuration database (`uvm_config_db`) |
| Consistent reporting | Built-in messaging with verbosity control |
| Object creation flexibility | Factory pattern for type overrides |

---

## 1.2 UVM Class Hierarchy

Every UVM class ultimately inherits from `uvm_void`. The key branches are:

```
uvm_void
├── uvm_object                    ← data / transaction classes
│   ├── uvm_transaction
│   │   └── uvm_sequence_item     ← items driven on interfaces
│   ├── uvm_sequence              ← stimulus generators
│   ├── uvm_reg_field / uvm_reg   ← register model classes
│   └── ...
└── uvm_component                 ← structural / persistent classes
    ├── uvm_driver
    ├── uvm_monitor
    ├── uvm_sequencer
    ├── uvm_agent
    ├── uvm_scoreboard
    ├── uvm_env
    └── uvm_test
```

### Key Distinction

- **`uvm_object`** -- lightweight, transient (transactions, configurations). Created and
  destroyed during simulation.
- **`uvm_component`** -- heavyweight, persistent (drivers, monitors). Created during the
  `build_phase` and live for the entire simulation. They form a **hierarchical tree** that
  mirrors the verification environment.

---

## 1.3 UVM Components in Detail

### 1.3.1 `uvm_driver`

The driver converts abstract transactions into pin-level activity on the DUT interface.

```systemverilog
class my_driver extends uvm_driver #(my_transaction);
  `uvm_component_utils(my_driver)

  virtual my_if vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual task run_phase(uvm_phase phase);
    forever begin
      seq_item_port.get_next_item(req);

      // Drive the transaction onto the interface
      @(posedge vif.clk);
      vif.addr  <= req.addr;
      vif.data  <= req.data;
      vif.valid <= 1'b1;
      @(posedge vif.clk);
      vif.valid <= 1'b0;

      seq_item_port.item_done();
    end
  endtask
endclass
```

**Key points:**

- Parameterized with the transaction type (`my_transaction`).
- Uses `seq_item_port` to pull items from the sequencer.
- Must call `item_done()` to signal completion to the sequencer.

### 1.3.2 `uvm_monitor`

The monitor passively observes the DUT interface and broadcasts transactions via an
analysis port.

```systemverilog
class my_monitor extends uvm_monitor;
  `uvm_component_utils(my_monitor)

  virtual my_if vif;
  uvm_analysis_port #(my_transaction) ap;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ap = new("ap", this);
  endfunction

  virtual task run_phase(uvm_phase phase);
    my_transaction tx;
    forever begin
      @(posedge vif.clk);
      if (vif.valid) begin
        tx = my_transaction::type_id::create("tx");
        tx.addr = vif.addr;
        tx.data = vif.data;
        ap.write(tx);
      end
    end
  endtask
endclass
```

**Key points:**

- Never drives signals -- observation only.
- Uses `uvm_analysis_port` for one-to-many broadcasting.
- Creates transactions using the factory (`type_id::create`).

### 1.3.3 `uvm_sequencer`

The sequencer arbitrates between multiple sequences and feeds transactions to the driver.

```systemverilog
class my_sequencer extends uvm_sequencer #(my_transaction);
  `uvm_component_utils(my_sequencer)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
endclass
```

In most cases the default `uvm_sequencer` is sufficient; custom sequencers add arbitration
policies or additional ports.

### 1.3.4 `uvm_agent`

The agent encapsulates a driver, monitor, and sequencer for one interface.

```systemverilog
class my_agent extends uvm_agent;
  `uvm_component_utils(my_agent)

  my_driver    drv;
  my_monitor   mon;
  my_sequencer sqr;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    mon = my_monitor::type_id::create("mon", this);
    if (get_is_active() == UVM_ACTIVE) begin
      drv = my_driver::type_id::create("drv", this);
      sqr = my_sequencer::type_id::create("sqr", this);
    end
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    if (get_is_active() == UVM_ACTIVE)
      drv.seq_item_port.connect(sqr.seq_item_export);
  endfunction
endclass
```

**Active vs. Passive agents:**

| Mode | Contains | Use Case |
|------|----------|----------|
| `UVM_ACTIVE` | Driver + Sequencer + Monitor | Drives and observes the interface |
| `UVM_PASSIVE` | Monitor only | Observe-only (e.g., reference interface) |

### 1.3.5 `uvm_env`

The environment instantiates agents, scoreboards, and any other structural components.

```systemverilog
class my_env extends uvm_env;
  `uvm_component_utils(my_env)

  my_agent      agt;
  my_scoreboard sb;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    agt = my_agent::type_id::create("agt", this);
    sb  = my_scoreboard::type_id::create("sb", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    agt.mon.ap.connect(sb.analysis_export);
  endfunction
endclass
```

### 1.3.6 `uvm_test`

The test is the top-level component. It creates the environment and starts sequences.

```systemverilog
class base_test extends uvm_test;
  `uvm_component_utils(base_test)

  my_env env;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = my_env::type_id::create("env", this);
  endfunction

  task run_phase(uvm_phase phase);
    my_sequence seq;
    phase.raise_objection(this);

    seq = my_sequence::type_id::create("seq");
    seq.start(env.agt.sqr);

    phase.drop_objection(this);
  endtask
endclass
```

---

## 1.4 UVM Phases

UVM simulation proceeds through a well-defined set of **phases**. Each phase is either a
**function phase** (executes in zero simulation time) or a **task phase** (consumes
simulation time).

### Phase Execution Order

```
             ┌────────────────────────────────────────┐
             │           FUNCTION PHASES              │
             │  (execute top-down or bottom-up,       │
             │   zero simulation time)                │
             ├────────────────────────────────────────┤
         1.  │  build_phase          (top → down)     │
         2.  │  connect_phase        (bottom → up)    │
         3.  │  end_of_elaboration_phase              │
         4.  │  start_of_simulation_phase             │
             ├────────────────────────────────────────┤
             │           TASK PHASES                  │
             │  (execute in parallel across all       │
             │   components, consume sim time)        │
             ├────────────────────────────────────────┤
         5.  │  run_phase                             │
             │    ├── reset_phase                     │
             │    ├── configure_phase                 │
             │    ├── main_phase                      │
             │    └── shutdown_phase                  │
             ├────────────────────────────────────────┤
             │           CLEANUP PHASES               │
             ├────────────────────────────────────────┤
         6.  │  extract_phase                         │
         7.  │  check_phase                           │
         8.  │  report_phase                          │
         9.  │  final_phase                           │
             └────────────────────────────────────────┘
```

### Phase Details

| Phase | Type | Direction | Purpose |
|-------|------|-----------|---------|
| `build_phase` | Function | Top-down | Create sub-components, configure objects |
| `connect_phase` | Function | Bottom-up | Connect TLM ports, analysis ports |
| `end_of_elaboration_phase` | Function | Bottom-up | Final topology adjustments |
| `start_of_simulation_phase` | Function | Bottom-up | Print topology, open files |
| `run_phase` | Task | Parallel | Main simulation activity |
| `extract_phase` | Function | Bottom-up | Extract results from scoreboards |
| `check_phase` | Function | Bottom-up | Check for errors |
| `report_phase` | Function | Bottom-up | Print final reports |
| `final_phase` | Function | Top-down | Close files, release resources |

### The Objection Mechanism

Task phases use **objections** to control when the phase ends. A phase will not end until
all objections have been dropped.

```systemverilog
task run_phase(uvm_phase phase);
  phase.raise_objection(this, "Starting test stimulus");

  // ... generate stimulus, wait for responses ...
  repeat(100) @(posedge vif.clk);

  phase.drop_objection(this, "Test stimulus complete");
endtask
```

**Rules of thumb:**

- Raise objections **only in the test** or the top-level sequence.
- Avoid raising objections in low-level components (drivers, monitors).
- The `drain_time` can be set to allow extra cycles after all objections are dropped:
  `phase.phase_done.set_drain_time(this, 100ns);`

---

## 1.5 The UVM Factory

The factory is one of UVM's most powerful features. It allows you to **override types
without modifying the original code**, which is essential for reuse.

### Registering with the Factory

Every UVM class must be registered:

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

### Creating Objects via the Factory

Always use factory creation instead of `new`:

```systemverilog
// Correct -- uses the factory
my_transaction tx = my_transaction::type_id::create("tx");
my_driver      drv = my_driver::type_id::create("drv", this);

// Wrong -- bypasses the factory, overrides will not work
my_transaction tx = new("tx");
```

### Factory Overrides

Override types globally or per-instance:

```systemverilog
class extended_transaction extends my_transaction;
  `uvm_object_utils(extended_transaction)

  rand bit [7:0] extra_field;

  function new(string name = "extended_transaction");
    super.new(name);
  endfunction
endclass

class error_injection_test extends base_test;
  `uvm_component_utils(error_injection_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    // Global type override: every my_transaction becomes extended_transaction
    my_transaction::type_id::set_type_override(extended_transaction::get_type());

    // Instance override: only the driver in env.agt gets the override
    // set_inst_override_by_type(
    //   my_transaction::get_type(),
    //   extended_transaction::get_type(),
    //   "env.agt.drv.*"
    // );

    super.build_phase(phase);
  endfunction
endclass
```

**Why this matters:** A VIP developed for one project can be reused in another simply by
overriding transaction types and components, without touching the original source.

---

## 1.6 Transaction-Level Modeling (TLM)

UVM uses TLM to pass data between components in a decoupled manner.

### TLM Port Types

| Port | Description | Cardinality |
|------|-------------|-------------|
| `uvm_analysis_port` | Broadcast (write) | 1-to-many |
| `uvm_analysis_imp` | Receive (write callback) | 1-to-1 |
| `uvm_analysis_export` | Pass-through | 1-to-1 |
| `uvm_tlm_analysis_fifo` | Buffered analysis connection | 1-to-1 |
| `uvm_blocking_put_port` | Blocking put | 1-to-1 |
| `uvm_blocking_get_port` | Blocking get | 1-to-1 |

### Analysis Port Example

The most common TLM pattern is the **analysis port → analysis implementation**:

```systemverilog
// --- Producer (Monitor) ---
class my_monitor extends uvm_monitor;
  uvm_analysis_port #(my_transaction) ap;

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ap = new("ap", this);
  endfunction

  task run_phase(uvm_phase phase);
    // ...
    ap.write(tx);  // broadcast to all subscribers
  endtask
endclass

// --- Consumer (Scoreboard) ---
class my_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(my_scoreboard)

  uvm_analysis_imp #(my_transaction, my_scoreboard) analysis_export;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    analysis_export = new("analysis_export", this);
  endfunction

  // Called every time the monitor broadcasts a transaction
  function void write(my_transaction tx);
    `uvm_info("SB", $sformatf("Received: addr=0x%0h data=0x%0h",
              tx.addr, tx.data), UVM_MEDIUM)
    // Compare with expected ...
  endfunction
endclass
```

### TLM FIFO for Decoupling

When the producer and consumer run at different rates, use a FIFO:

```systemverilog
class my_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(my_scoreboard)

  uvm_tlm_analysis_fifo #(my_transaction) expected_fifo;
  uvm_tlm_analysis_fifo #(my_transaction) actual_fifo;

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    expected_fifo = new("expected_fifo", this);
    actual_fifo   = new("actual_fifo", this);
  endfunction

  task run_phase(uvm_phase phase);
    my_transaction exp_tx, act_tx;
    forever begin
      expected_fifo.get(exp_tx);
      actual_fifo.get(act_tx);
      if (!exp_tx.compare(act_tx))
        `uvm_error("SB", "Mismatch detected!")
    end
  endtask
endclass
```

---

## 1.7 Transactions and Field Automation

### Defining a Transaction

```systemverilog
class my_transaction extends uvm_sequence_item;
  `uvm_object_utils(my_transaction)

  rand bit [7:0]  addr;
  rand bit [31:0] data;
  rand bit        write;

  constraint c_addr { addr inside {[8'h00 : 8'hFF]}; }
  constraint c_data { data dist { 0 := 10, [1:32'hFFFF_FFFE] := 80, 32'hFFFF_FFFF := 10 }; }

  function new(string name = "my_transaction");
    super.new(name);
  endfunction

  function string convert2string();
    return $sformatf("addr=0x%02h data=0x%08h write=%0b", addr, data, write);
  endfunction

  function bit do_compare(uvm_object rhs, uvm_comparer comparer);
    my_transaction rhs_;
    if (!$cast(rhs_, rhs)) return 0;
    return (addr  == rhs_.addr) &&
           (data  == rhs_.data) &&
           (write == rhs_.write);
  endfunction

  function void do_copy(uvm_object rhs);
    my_transaction rhs_;
    super.do_copy(rhs);
    $cast(rhs_, rhs);
    addr  = rhs_.addr;
    data  = rhs_.data;
    write = rhs_.write;
  endfunction
endclass
```

### Field Macros (Alternative Approach)

UVM provides field automation macros that auto-generate `copy`, `compare`, `print`,
`pack`, and `unpack`:

```systemverilog
class my_transaction extends uvm_sequence_item;
  `uvm_object_utils_begin(my_transaction)
    `uvm_field_int(addr,  UVM_ALL_ON)
    `uvm_field_int(data,  UVM_ALL_ON)
    `uvm_field_int(write, UVM_ALL_ON)
  `uvm_object_utils_end

  rand bit [7:0]  addr;
  rand bit [31:0] data;
  rand bit        write;

  function new(string name = "my_transaction");
    super.new(name);
  endfunction
endclass
```

> **Trade-off:** Field macros are convenient but add simulation overhead. For
> performance-critical environments, implement `do_compare`, `do_copy`, `do_print`
> manually.

---

## 1.8 Putting It All Together -- Minimal Testbench Skeleton

```systemverilog
// ──────────────── Interface ────────────────
interface my_if(input logic clk);
  logic [7:0]  addr;
  logic [31:0] data;
  logic        valid;
  logic        write;
endinterface

// ──────────────── Top Module ────────────────
module top;
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  logic clk = 0;
  always #5 clk = ~clk;

  my_if dut_if(clk);

  // DUT instantiation (placeholder)
  // my_dut dut(.clk(clk), .addr(dut_if.addr), ...);

  initial begin
    uvm_config_db#(virtual my_if)::set(null, "*", "vif", dut_if);
    run_test("base_test");
  end
endmodule
```

This skeleton demonstrates the standard flow:

1. Declare a **SystemVerilog interface** to connect the testbench to the DUT.
2. Store the virtual interface in the **config database**.
3. Call `run_test()` to start UVM -- it creates the test, builds the hierarchy, and runs
   through all phases automatically.

---

**Next:** [Chapter 2 -- UVM Intermediate](02_uvm_intermediate.md)
