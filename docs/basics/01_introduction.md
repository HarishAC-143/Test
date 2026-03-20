# Chapter 1: Introduction to UVM

## What Is UVM?

UVM (Universal Verification Methodology) is a standardized, class-based framework written in SystemVerilog for building modular, reusable, and scalable verification environments. It is maintained as IEEE 1800.2 and is supported by all major EDA vendors.

Before UVM, verification teams used proprietary methodologies such as VMM (Synopsys), OVM (Cadence/Mentor), and eRM (Cadence). UVM unified these approaches into a single open standard.

## Why UVM?

| Challenge | How UVM Solves It |
|-----------|-------------------|
| Testbench reuse across projects | Standardized component architecture with agents, envs, and tests |
| Stimulus generation | Constrained-random sequences with coverage-driven closure |
| Checking correctness | Scoreboards connected via TLM analysis ports |
| Configuration flexibility | `uvm_config_db` for passing settings without recompilation |
| Debug and reporting | Built-in messaging with verbosity control |
| Interoperability | IEEE standard — works across VCS, Xcelium, Questa, Riviera-PRO |

## Where UVM Fits in the Verification Flow

```
┌──────────────────────────────────────────────────┐
│                  Verification Plan               │
│  (Features, Coverage Goals, Test Scenarios)       │
└──────────────┬───────────────────────────────────┘
               │
               ▼
┌──────────────────────────────────────────────────┐
│              UVM Testbench                        │
│  ┌────────┐ ┌─────────┐ ┌──────────┐            │
│  │ Tests  │ │ Env     │ │ Agents   │            │
│  │        │→│         │→│ (Drv,Mon)│→ DUT       │
│  └────────┘ └─────────┘ └──────────┘            │
│        ↑         ↑            │                  │
│   Sequences  Scoreboard  Coverage                │
└──────────────────────────────────────────────────┘
               │
               ▼
┌──────────────────────────────────────────────────┐
│         Coverage Closure & Sign-off              │
└──────────────────────────────────────────────────┘
```

## A Minimal UVM Example

This is the smallest possible UVM testbench — it does nothing useful but shows the essential skeleton.

```systemverilog
// file: hello_uvm.sv
`include "uvm_macros.svh"
import uvm_pkg::*;

class hello_test extends uvm_test;
  `uvm_component_utils(hello_test)

  function new(string name = "hello_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    `uvm_info("HELLO", "Hello from UVM!", UVM_LOW)
    #100;
    phase.drop_objection(this);
  endtask
endclass

module top;
  initial begin
    run_test("hello_test");
  end
endmodule
```

### What Happens When You Run This

1. `run_test("hello_test")` asks the UVM factory to create an instance of `hello_test`.
2. UVM walks through its **phases** (build → connect → run → …).
3. During `run_phase`, the test raises an objection (keeping the simulator alive), prints a message, waits 100 time units, then drops the objection.
4. When all objections are dropped, UVM proceeds to the extract/check/report phases and the simulation ends.

### Key Observations

- **`uvm_component_utils`** registers `hello_test` with the UVM factory so it can be created by name.
- **`run_test()`** is the single entry point that bootstraps the entire UVM environment.
- **Objections** control simulation lifetime — if no one raises an objection, `run_phase` ends immediately.

## UVM Testbench Architecture at a Glance

```
                     uvm_test
                        │
                     uvm_env
                    /        \
            uvm_agent       uvm_agent
           /    |    \          ...
    uvm_driver  │  uvm_monitor
          uvm_sequencer
                │
          uvm_sequence
                │
        uvm_sequence_item
```

| Component | Responsibility |
|-----------|---------------|
| `uvm_test` | Top-level test that configures and starts the environment |
| `uvm_env` | Container that groups agents, scoreboards, and coverage collectors |
| `uvm_agent` | Encapsulates a driver, monitor, and sequencer for one interface |
| `uvm_driver` | Translates sequence items into pin-level activity on the DUT |
| `uvm_monitor` | Observes DUT signals and converts them into transactions |
| `uvm_sequencer` | Arbitrates between sequences and feeds items to the driver |
| `uvm_sequence` | Generates a stream of `uvm_sequence_item` objects |
| `uvm_sequence_item` | A single transaction (e.g., a bus read, a packet) |
| `uvm_scoreboard` | Compares expected vs. actual behavior |

## Terminology Quick Reference

| Term | Meaning |
|------|---------|
| **DUT** | Design Under Test — the RTL being verified |
| **Testbench** | The verification environment surrounding the DUT |
| **Transaction** | An abstract representation of a bus cycle, packet, etc. |
| **Sequence** | An ordered generator of transactions |
| **Phase** | A stage of simulation (build, connect, run, etc.) |
| **Objection** | A mechanism to prevent a phase from ending prematurely |
| **Factory** | A creation pattern that enables type overrides at runtime |
| **Config DB** | A global database for sharing configuration across hierarchy |
| **TLM** | Transaction Level Modeling — port-based inter-component communication |

## Next Steps

Continue to [Chapter 2: UVM Class Hierarchy](02_class_hierarchy.md) to understand how all UVM classes relate to each other.
