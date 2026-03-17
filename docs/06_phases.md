# Chapter 6: UVM Phases

## What Are Phases?

UVM phases provide an **ordered execution framework** that coordinates the construction, connection, simulation, and cleanup of all testbench components. Instead of writing custom initialization code in `initial` blocks, UVM components implement specific phase callbacks that are invoked automatically in the correct order.

## Phase Categories

UVM phases fall into three categories:

```
 Build-time Phases        Run-time Phases         Clean-up Phases
 (functions)              (tasks — consume time)   (functions)
 ─────────────────        ────────────────────     ──────────────────
 ┌──────────────┐         ┌──────────────────┐     ┌───────────────┐
 │  build_phase │    ┌───►│   reset_phase    │     │ extract_phase │
 └──────┬───────┘    │    └────────┬─────────┘     └───────┬───────┘
        ▼            │             ▼                       ▼
 ┌──────────────┐    │    ┌──────────────────┐     ┌───────────────┐
 │connect_phase │    │    │ configure_phase  │     │  check_phase  │
 └──────┬───────┘    │    └────────┬─────────┘     └───────┬───────┘
        ▼            │             ▼                       ▼
 ┌──────────────────┐│    ┌──────────────────┐     ┌───────────────┐
 │end_of_elaboration││    │   main_phase     │     │ report_phase  │
 └──────┬───────────┘│    └────────┬─────────┘     └───────┬───────┘
        ▼            │             ▼                       ▼
 ┌──────────────────┐│    ┌──────────────────┐     ┌───────────────┐
 │start_of_simulation│    │ shutdown_phase   │     │  final_phase  │
 └──────┬───────────┘│    └──────────────────┘     └───────────────┘
        ▼            │
 ┌──────────────┐    │
 │  run_phase ──┼────┘ (run_phase runs in parallel
 └──────────────┘       with the sub-phases above)
```

## The Common Phases (What You Use 90% of the Time)

Most testbenches only use these four phases:

### 1. `build_phase` — Construct the Hierarchy

**Type:** Function (zero-time)
**Execution order:** Top-down (parent before children)

This is where you create sub-components and configure them:

```systemverilog
function void build_phase(uvm_phase phase);
  super.build_phase(phase);
  
  // Create sub-components
  agent      = my_agent::type_id::create("agent", this);
  scoreboard = my_scoreboard::type_id::create("scoreboard", this);
  
  // Set configuration for children
  uvm_config_db #(virtual my_if)::set(this, "agent.*", "vif", vif);
endfunction
```

> **Top-down execution** means the test's `build_phase` runs first, then the environment's, then the agent's, then the driver's. This ensures parents can configure children before children are built.

### 2. `connect_phase` — Wire Components Together

**Type:** Function (zero-time)
**Execution order:** Bottom-up (children before parents)

This is where you connect TLM ports:

```systemverilog
function void connect_phase(uvm_phase phase);
  super.connect_phase(phase);
  
  // Connect driver to sequencer
  driver.seq_item_port.connect(sequencer.seq_item_export);
  
  // Connect monitor to scoreboard
  monitor.ap.connect(scoreboard.analysis_export);
endfunction
```

> **Bottom-up execution** means children's ports exist before the parent tries to connect them.

### 3. `run_phase` — Simulate

**Type:** Task (consumes simulation time)
**Execution order:** All components run in parallel

This is where the actual verification happens:

```systemverilog
task run_phase(uvm_phase phase);
  phase.raise_objection(this);
  
  // Start sequences, wait for completion, etc.
  my_seq seq = my_seq::type_id::create("seq");
  seq.start(env.agent.sequencer);
  
  phase.drop_objection(this);
endtask
```

### 4. `report_phase` — Summarize Results

**Type:** Function (zero-time)
**Execution order:** Bottom-up

Print final statistics, coverage summaries, etc.:

```systemverilog
function void report_phase(uvm_phase phase);
  super.report_phase(phase);
  `uvm_info("REPORT", $sformatf("Total transactions: %0d", txn_count), UVM_LOW)
  `uvm_info("REPORT", $sformatf("Pass: %0d  Fail: %0d", pass_count, fail_count), UVM_LOW)
endfunction
```

## Phase Execution Order in Detail

Here is the complete execution flow for a typical simulation:

```
Phase                      Execution     Time
────────────────────────── ──────────── ─────
1. build_phase             Top-down      0
2. connect_phase           Bottom-up     0
3. end_of_elaboration      Bottom-up     0
4. start_of_simulation     Bottom-up     0
5. run_phase               Parallel      >0   ◄── Simulation happens here
6. extract_phase           Bottom-up     0
7. check_phase             Bottom-up     0
8. report_phase            Bottom-up     0
9. final_phase             Top-down      0
```

## Objections — Controlling Simulation Duration

The `run_phase` continues as long as at least one component has a **raised objection**. When all objections are dropped, `run_phase` ends.

### Basic Objection Pattern

```systemverilog
task run_phase(uvm_phase phase);
  phase.raise_objection(this);    // "Don't end yet, I have work to do"
  
  // Do verification work...
  #1000;
  
  phase.drop_objection(this);     // "I'm done, simulation can end"
endtask
```

### Objection in Practice

Typically, objections are raised/dropped in the test:

```systemverilog
class my_test extends uvm_test;
  task run_phase(uvm_phase phase);
    my_sequence seq;
    
    phase.raise_objection(this, "Starting test sequence");
    
    seq = my_sequence::type_id::create("seq");
    seq.start(env.agent.sequencer);
    
    // Drain time — let remaining transactions propagate
    #100;
    
    phase.drop_objection(this, "Test sequence complete");
  endtask
endclass
```

### What Happens If No One Raises an Objection?

If no component raises an objection during `run_phase`, the phase completes immediately and the simulation ends after the build-time phases. This is a common mistake:

```systemverilog
// BUG: Simulation ends immediately because no objection is raised!
task run_phase(uvm_phase phase);
  my_sequence seq = my_sequence::type_id::create("seq");
  seq.start(env.agent.sequencer);  // Never executes because phase ends
endtask
```

## The `end_of_elaboration_phase`

Useful for final checks after all components are built and connected:

```systemverilog
function void end_of_elaboration_phase(uvm_phase phase);
  super.end_of_elaboration_phase(phase);
  
  // Print the component hierarchy for debugging
  uvm_top.print_topology();
endfunction
```

## The `start_of_simulation_phase`

Run right before `run_phase` — good for printing simulation configuration:

```systemverilog
function void start_of_simulation_phase(uvm_phase phase);
  super.start_of_simulation_phase(phase);
  `uvm_info("CFG", $sformatf("Running with %0d agents", num_agents), UVM_LOW)
endfunction
```

## The Extract and Check Phases

Used after `run_phase` to collect and verify results:

```systemverilog
// Extract: Collect final data from the DUT or monitors
function void extract_phase(uvm_phase phase);
  super.extract_phase(phase);
  final_coverage = $get_coverage();
endfunction

// Check: Verify final conditions
function void check_phase(uvm_phase phase);
  super.check_phase(phase);
  if (fail_count > 0)
    `uvm_error("CHECK", $sformatf("%0d transactions failed", fail_count))
endfunction
```

## Phase Jumping and Resets (Advanced)

UVM supports jumping between phases, which is useful for reset testing:

```systemverilog
task main_phase(uvm_phase phase);
  phase.raise_objection(this);
  
  // Run normal operation
  normal_seq.start(sequencer);
  
  // Jump back to reset_phase to test reset recovery
  phase.jump(uvm_reset_phase::get());
  
  phase.drop_objection(this);
endtask
```

## Common Mistakes

| Mistake | Symptom | Fix |
|---------|---------|-----|
| Not calling `super.build_phase(phase)` | Config not propagated | Always call `super.xxx_phase(phase)` |
| Creating components in `connect_phase` | Component not in hierarchy | Create in `build_phase` |
| Forgetting `raise_objection` | Simulation ends immediately | Add objection in `run_phase` |
| Connecting ports in `build_phase` | Child ports don't exist yet | Connect in `connect_phase` |

## Summary

| Phase | Type | Order | Purpose |
|-------|------|-------|---------|
| `build_phase` | Function | Top-down | Create sub-components |
| `connect_phase` | Function | Bottom-up | Wire TLM ports |
| `end_of_elaboration_phase` | Function | Bottom-up | Final elaboration checks |
| `start_of_simulation_phase` | Function | Bottom-up | Pre-simulation setup |
| `run_phase` | Task | Parallel | Main simulation |
| `extract_phase` | Function | Bottom-up | Collect final data |
| `check_phase` | Function | Bottom-up | Verify final state |
| `report_phase` | Function | Bottom-up | Print results |
| `final_phase` | Function | Top-down | Final cleanup |

---

[← Previous: Chapter 5 — Sequences](05_sequences.md) | [Next: Chapter 7 — TLM Ports & Communication →](07_tlm.md)
