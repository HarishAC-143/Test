# Chapter 4: UVM Phases

## What Are Phases?

UVM divides simulation into a sequence of well-defined **phases**. Each phase has a specific purpose, and every `uvm_component` in the hierarchy participates. Phases are executed in a fixed order, and UVM guarantees that all components complete one phase before the next begins.

## Phase Execution Order

```
                        ┌─────────────────┐
                        │   build_phase    │  top-down
                        └────────┬────────┘
                        ┌────────▼────────┐
                        │  connect_phase   │  bottom-up
                        └────────┬────────┘
                        ┌────────▼────────┐
                        │end_of_elab_phase │  bottom-up
                        └────────┬────────┘
                        ┌────────▼────────┐
                        │start_of_sim_phase│  bottom-up
                        └────────┬────────┘
                   ┌─────────────▼──────────────┐
                   │        run_phase            │  parallel (task)
                   │  ┌──────────────────────┐   │
                   │  │   reset_phase        │   │
                   │  │   configure_phase    │   │  sub-phases
                   │  │   main_phase         │   │  (also parallel tasks)
                   │  │   shutdown_phase     │   │
                   │  └──────────────────────┘   │
                   └─────────────┬──────────────┘
                        ┌────────▼────────┐
                        │  extract_phase   │  bottom-up
                        └────────┬────────┘
                        ┌────────▼────────┐
                        │   check_phase    │  bottom-up
                        └────────┬────────┘
                        ┌────────▼────────┐
                        │  report_phase    │  bottom-up
                        └────────┬────────┘
                        ┌────────▼────────┐
                        │   final_phase    │  top-down
                        └─────────────────┘
```

## Phase Categories

### Functions (Zero-Time)

These phases execute in **zero simulation time**. They are implemented as `function void`, not tasks.

| Phase | Order | Purpose |
|-------|-------|---------|
| `build_phase` | Top-down | Create child components, set configuration |
| `connect_phase` | Bottom-up | Connect TLM ports and exports |
| `end_of_elaboration_phase` | Bottom-up | Final adjustments after all connections are made |
| `start_of_simulation_phase` | Bottom-up | Print banners, open files, last-minute checks |
| `extract_phase` | Bottom-up | Extract results from the DUT or scoreboard |
| `check_phase` | Bottom-up | Verify expected results, report errors |
| `report_phase` | Bottom-up | Generate final reports and summaries |
| `final_phase` | Top-down | Clean up resources |

### Tasks (Time-Consuming)

The `run_phase` and its sub-phases consume simulation time. They run as **parallel tasks** across all components.

| Phase | Purpose |
|-------|---------|
| `run_phase` | Main simulation — runs in parallel with sub-phases |
| `reset_phase` | Apply and release reset |
| `configure_phase` | Program DUT registers |
| `main_phase` | Core test stimulus |
| `shutdown_phase` | Drain remaining transactions, clean up |

## Execution Direction

- **Top-down**: Parent's phase executes before children (e.g., `build_phase`).
- **Bottom-up**: Children's phase executes before parent (e.g., `connect_phase`).

This matters! In `build_phase`, the parent creates children first, so children exist when their own `build_phase` runs. In `connect_phase`, children's ports are ready before the parent tries to connect them.

## Objections

Since `run_phase` is a task that can consume time, UVM needs a way to know when to stop. This is done with **objections**.

```systemverilog
task run_phase(uvm_phase phase);
  phase.raise_objection(this, "Starting stimulus");   // keep phase alive
  // ... do work ...
  phase.drop_objection(this, "Stimulus complete");    // allow phase to end
endtask
```

### Rules

1. If **no component** raises an objection, the phase ends immediately.
2. The phase ends when **all raised objections have been dropped**.
3. Always raise objections at the **test level** or the **sequence level** — not in drivers or monitors.

### Drain Time

You can add a drain time to let residual transactions complete:

```systemverilog
function void build_phase(uvm_phase phase);
  super.build_phase(phase);
  uvm_config_db #(uvm_object_wrapper)::set(this, "env.agent.sqr.run_phase",
    "default_sequence", my_sequence::type_id::get());
  phase.phase_done.set_drain_time(this, 200ns);
endfunction
```

## Phase Implementation Examples

### build_phase (Top-Down)

```systemverilog
function void build_phase(uvm_phase phase);
  super.build_phase(phase);
  // Create children
  agent = my_agent::type_id::create("agent", this);
  scoreboard = my_scoreboard::type_id::create("scoreboard", this);

  // Pass configuration down
  uvm_config_db #(int)::set(this, "agent", "num_lanes", 4);
endfunction
```

### connect_phase (Bottom-Up)

```systemverilog
function void connect_phase(uvm_phase phase);
  super.connect_phase(phase);
  // Connect monitor's analysis port to scoreboard
  agent.mon.ap.connect(scoreboard.analysis_export);
  // Connect driver to sequencer
  agent.drv.seq_item_port.connect(agent.sqr.seq_item_export);
endfunction
```

### end_of_elaboration_phase

```systemverilog
function void end_of_elaboration_phase(uvm_phase phase);
  super.end_of_elaboration_phase(phase);
  // Print the component hierarchy for debug
  uvm_top.print_topology();
endfunction
```

### start_of_simulation_phase

```systemverilog
function void start_of_simulation_phase(uvm_phase phase);
  super.start_of_simulation_phase(phase);
  `uvm_info("SIM", $sformatf("Starting simulation with %0d transactions",
            num_transactions), UVM_LOW)
endfunction
```

### run_phase

```systemverilog
task run_phase(uvm_phase phase);
  phase.raise_objection(this);

  // Reset
  reset_dut();

  // Configure
  program_registers();

  // Main test
  fork
    send_stimulus();
    monitor_responses();
  join

  phase.drop_objection(this);
endtask
```

### extract_phase

```systemverilog
function void extract_phase(uvm_phase phase);
  super.extract_phase(phase);
  // Pull coverage percentage
  coverage_pct = $get_coverage();
endfunction
```

### check_phase

```systemverilog
function void check_phase(uvm_phase phase);
  super.check_phase(phase);
  if (error_count > 0)
    `uvm_error("CHECK", $sformatf("%0d errors detected", error_count))
endfunction
```

### report_phase

```systemverilog
function void report_phase(uvm_phase phase);
  super.report_phase(phase);
  `uvm_info("REPORT", $sformatf(
    "\n========================================\n" +
    "  Transactions: %0d\n" +
    "  Pass: %0d  Fail: %0d\n" +
    "  Coverage: %0.1f%%\n" +
    "========================================",
    total_txn, pass_count, fail_count, coverage_pct), UVM_LOW)
endfunction
```

## run_phase vs. Sub-Phases

You can use **either** `run_phase` **or** the sub-phases (`reset_phase`, `configure_phase`, `main_phase`, `shutdown_phase`), but mixing them requires care:

- `run_phase` runs **in parallel** with all sub-phases.
- If you raise an objection in `run_phase`, it does **not** affect sub-phase progression.
- In practice, most teams use only `run_phase` and handle reset/config/main internally.

```systemverilog
// Using sub-phases (less common but more structured)
task reset_phase(uvm_phase phase);
  phase.raise_objection(this);
  vif.rst_n <= 1'b0;
  repeat(10) @(posedge vif.clk);
  vif.rst_n <= 1'b1;
  repeat(5) @(posedge vif.clk);
  phase.drop_objection(this);
endtask

task main_phase(uvm_phase phase);
  phase.raise_objection(this);
  begin
    my_sequence seq = my_sequence::type_id::create("seq");
    seq.start(env.agent.sqr);
  end
  phase.drop_objection(this);
endtask
```

## Phase Jumping (Advanced)

UVM allows jumping to a different phase (e.g., jump back to `reset_phase` after an error):

```systemverilog
task main_phase(uvm_phase phase);
  phase.raise_objection(this);
  // ... run test ...
  if (need_reset) begin
    phase.jump(uvm_reset_phase::get());  // jump back to reset
  end
  phase.drop_objection(this);
endtask
```

**Use phase jumping sparingly** — it can create hard-to-debug simulation behavior.

## Summary

| Concept | Details |
|---------|---------|
| Phase order | build → connect → end_of_elab → start_of_sim → **run** → extract → check → report → final |
| Time-consuming | Only `run_phase` and its sub-phases consume simulation time |
| Direction | `build_phase` is top-down; most others are bottom-up |
| Objections | Raise in `run_phase` to keep simulation alive; drop when done |
| Sub-phases | `reset`, `configure`, `main`, `shutdown` — run inside `run_phase` |

## Next Steps

Continue to [Chapter 5: Sequences and Sequence Items](05_sequences.md) to learn how to generate stimulus.
