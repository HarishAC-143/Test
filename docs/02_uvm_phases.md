# 2. UVM Phases & Lifecycle

[&larr; Previous: UVM Basics](01_uvm_basics.md) | [Back to Main](../README.md) | [Next: TLM & Communication &rarr;](03_uvm_tlm.md)

---

## 2.1 Overview

UVM uses a **phased execution model** to ensure that all testbench components are built, connected, and initialized in the correct order before simulation begins. Phases execute in a well-defined sequence, and every `uvm_component` participates automatically.

There are three categories of phases:

| Category | Execution | Purpose |
|----------|-----------|---------|
| **Build phases** | Top-down | Construct and configure components |
| **Run phases** | Parallel (all components run concurrently) | Drive stimulus, monitor, check |
| **Cleanup phases** | Bottom-up | Report results, close files |

---

## 2.2 Phase Execution Order

```
┌─────────────────────── Build Phases ───────────────────────┐
│                                                            │
│  1. build_phase        (top-down, function)                │
│  2. connect_phase      (bottom-up, function)               │
│  3. end_of_elaboration_phase (bottom-up, function)         │
│                                                            │
├─────────────────────── Run-time Phases ────────────────────┤
│                                                            │
│  4. start_of_simulation_phase (bottom-up, function)        │
│                                                            │
│  5. run_phase          (parallel task — all components)     │
│     ├── reset_phase                                        │
│     ├── configure_phase                                    │
│     ├── main_phase                                         │
│     └── shutdown_phase                                     │
│                                                            │
├─────────────────────── Cleanup Phases ─────────────────────┤
│                                                            │
│  6. extract_phase      (bottom-up, function)               │
│  7. check_phase        (bottom-up, function)               │
│  8. report_phase       (bottom-up, function)               │
│  9. final_phase        (top-down, function)                │
│                                                            │
└────────────────────────────────────────────────────────────┘
```

### Important Notes

- **Functions** cannot consume simulation time. They execute and return immediately.
- **Tasks** (only `run_phase` and the sub-phases) can consume simulation time using `@`, `#`, `wait`, etc.
- `build_phase` executes **top-down** so parents create children first.
- `connect_phase` executes **bottom-up** so children are fully built before parents wire them together.

---

## 2.3 Detailed Phase Descriptions

### 2.3.1 `build_phase` (Top-Down, Function)

This is where you construct sub-components and retrieve configuration.

```systemverilog
virtual function void build_phase(uvm_phase phase);
  super.build_phase(phase);

  // Create sub-components using the factory
  agt = alu_agent::type_id::create("agt", this);

  // Retrieve configuration
  if (!uvm_config_db#(virtual alu_if)::get(this, "", "vif", vif))
    `uvm_fatal("BUILD", "Failed to get virtual interface")
endfunction
```

**Rules:**
- Always call `super.build_phase(phase)` first.
- Use `type_id::create()` (not `new()`) for factory support.
- Never connect ports here — children may not exist yet.

### 2.3.2 `connect_phase` (Bottom-Up, Function)

Wire TLM ports, analysis ports, and other connections.

```systemverilog
virtual function void connect_phase(uvm_phase phase);
  super.connect_phase(phase);

  // Connect driver to sequencer
  drv.seq_item_port.connect(sqr.seq_item_export);

  // Connect monitor to scoreboard
  mon.ap.connect(sb.analysis_export);
endfunction
```

**Rules:**
- All child components are guaranteed to be built at this point.
- Port-to-export and port-to-imp connections happen here.

### 2.3.3 `end_of_elaboration_phase` (Bottom-Up, Function)

Optional. Use for final adjustments after all connections are made.

```systemverilog
virtual function void end_of_elaboration_phase(uvm_phase phase);
  super.end_of_elaboration_phase(phase);
  // Print the component hierarchy for debugging
  uvm_top.print_topology();
endfunction
```

### 2.3.4 `start_of_simulation_phase` (Bottom-Up, Function)

Optional. Runs just before simulation. Good for printing banners or configuration summaries.

```systemverilog
virtual function void start_of_simulation_phase(uvm_phase phase);
  super.start_of_simulation_phase(phase);
  `uvm_info("SOS", "Simulation is about to start", UVM_LOW)
endfunction
```

### 2.3.5 `run_phase` (Parallel, Task)

The main simulation phase. All components' `run_phase` tasks execute **concurrently**.

```systemverilog
virtual task run_phase(uvm_phase phase);
  phase.raise_objection(this);

  // Drive stimulus, wait for events, etc.
  repeat (100) begin
    @(posedge vif.clk);
    // ... do work ...
  end

  phase.drop_objection(this);
endtask
```

### 2.3.6 Cleanup Phases

| Phase | Purpose |
|-------|---------|
| `extract_phase` | Extract data from scoreboards, collect results |
| `check_phase` | Perform final checks (e.g., FIFO empty checks) |
| `report_phase` | Print final pass/fail summary |
| `final_phase` | Close files, release resources |

---

## 2.4 Objections — Controlling When Simulation Ends

UVM uses an **objection mechanism** to determine when the `run_phase` (or any runtime phase) should end. The phase does not complete until all objections are dropped.

### Basic Pattern

```systemverilog
virtual task run_phase(uvm_phase phase);
  phase.raise_objection(this, "Starting test sequence");

  // ... run test stimulus ...
  my_seq.start(env.agt.sqr);

  phase.drop_objection(this, "Test sequence complete");
endtask
```

### Rules

1. **Raise before any time-consuming work.** If no component raises an objection, `run_phase` ends immediately.
2. **Drop when done.** Forgetting to drop causes the simulation to hang.
3. **Only raise/drop in `uvm_test` or `uvm_sequence`.** Avoid raising objections in drivers/monitors — they run forever and shouldn't control simulation lifetime.

### Drain Time

You can add a drain time to allow in-flight transactions to complete after all objections are dropped:

```systemverilog
virtual function void build_phase(uvm_phase phase);
  super.build_phase(phase);
  // Allow 100ns after last objection drop
  uvm_objection::get_objection("run").set_drain_time(this, 100ns);
endfunction
```

Or more commonly in the test:

```systemverilog
virtual task run_phase(uvm_phase phase);
  phase.raise_objection(this);
  phase.get_objection().set_drain_time(this, 100);

  my_seq.start(env.agt.sqr);

  phase.drop_objection(this);
endtask
```

---

## 2.5 Run-Phase Sub-Phases

The `run_phase` executes in parallel with a set of fine-grained sub-phases. You can use either `run_phase` alone or the sub-phases — **not both** for the same component.

```
run_phase (runs in parallel with sub-phases below)
│
├── pre_reset_phase
├── reset_phase         ← assert/deassert reset
├── post_reset_phase
├── pre_configure_phase
├── configure_phase     ← program DUT registers
├── post_configure_phase
├── pre_main_phase
├── main_phase          ← primary stimulus
├── post_main_phase
├── pre_shutdown_phase
├── shutdown_phase      ← graceful completion
└── post_shutdown_phase
```

### Example: Using Sub-Phases in a Driver

```systemverilog
class my_driver extends uvm_driver #(my_txn);

  `uvm_component_utils(my_driver)

  virtual my_if vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual task reset_phase(uvm_phase phase);
    phase.raise_objection(this);
    vif.data  <= '0;
    vif.valid <= '0;
    @(posedge vif.rst_n);  // wait for reset deassert
    repeat(5) @(posedge vif.clk);
    phase.drop_objection(this);
  endtask

  virtual task main_phase(uvm_phase phase);
    my_txn txn;
    forever begin
      seq_item_port.get_next_item(txn);
      drive_txn(txn);
      seq_item_port.item_done();
    end
  endtask

  // ...
endclass
```

---

## 2.6 Phase Jumping

UVM allows jumping between phases — for example, going back to `reset_phase` to test reset recovery.

```systemverilog
virtual task main_phase(uvm_phase phase);
  // ... run some stimulus ...

  // Jump back to reset phase
  phase.jump(uvm_reset_phase::get());
endtask
```

**Caution:** Phase jumping is powerful but can make testbenches harder to debug. Use it sparingly.

---

## 2.7 Custom Phases

You can define custom phases for project-specific needs:

```systemverilog
class my_custom_phase extends uvm_task_phase;
  static local my_custom_phase m_inst;

  static function my_custom_phase get();
    if (m_inst == null)
      m_inst = new();
    return m_inst;
  endfunction

  function new(string name = "my_custom_phase");
    super.new(name);
  endfunction

  virtual task exec_task(uvm_component comp, uvm_phase phase);
    // Execute the custom phase on each component
  endtask
endclass
```

---

## 2.8 Complete Phase Lifecycle Diagram

```
    Time ──────────────────────────────────────────────────►

    ┌──────┐ ┌───────┐ ┌──────────────┐ ┌────────────────┐
    │build │ │connect│ │end_of_elab   │ │start_of_sim    │
    │(↓)   │ │(↑)    │ │(↑)           │ │(↑)             │
    └──┬───┘ └───┬───┘ └──────┬───────┘ └───────┬────────┘
       │         │            │                  │
       ▼         ▼            ▼                  ▼
    ┌──────────────────────────────────────────────────────┐
    │              run_phase (concurrent task)             │
    │  ┌─────┐┌──────┐┌──────┐┌──────┐┌────────┐         │
    │  │reset││config││ main ││ shut ││(others)│         │
    │  └─────┘└──────┘└──────┘└──────┘└────────┘         │
    │                                                      │
    │  Objections control when each sub-phase ends         │
    └──────────────────────────────────────────────────────┘
       │
       ▼
    ┌───────┐ ┌─────┐ ┌──────┐ ┌─────┐
    │extract│ │check│ │report│ │final│
    │(↑)    │ │(↑)  │ │(↑)   │ │(↓)  │
    └───────┘ └─────┘ └──────┘ └─────┘

    (↓) = top-down    (↑) = bottom-up
```

---

## 2.9 Summary

| Phase | Direction | Type | Purpose |
|-------|-----------|------|---------|
| `build_phase` | Top-down | Function | Create components, get config |
| `connect_phase` | Bottom-up | Function | Wire TLM ports |
| `end_of_elaboration_phase` | Bottom-up | Function | Final adjustments |
| `start_of_simulation_phase` | Bottom-up | Function | Pre-simulation setup |
| `run_phase` | Parallel | Task | Main simulation |
| `extract_phase` | Bottom-up | Function | Collect results |
| `check_phase` | Bottom-up | Function | Final checks |
| `report_phase` | Bottom-up | Function | Print summary |
| `final_phase` | Top-down | Function | Cleanup |

---

[&larr; Previous: UVM Basics](01_uvm_basics.md) | [Next: TLM & Communication &rarr;](03_uvm_tlm.md)
