# Chapter 9: UVM Reporting & Messaging

## Overview

UVM provides a comprehensive **reporting system** for logging messages, warnings, errors, and fatal conditions during simulation. Every `uvm_component` and `uvm_object` inherits this capability, giving you consistent, structured output with severity levels, verbosity control, and message filtering.

## The Four Severity Levels

UVM defines four message severity levels:

| Macro | Severity | Default Action | When to Use |
|-------|----------|---------------|-------------|
| `` `uvm_info `` | `UVM_INFO` | Display | Status updates, debug information |
| `` `uvm_warning `` | `UVM_WARNING` | Display | Recoverable issues, unexpected but non-fatal conditions |
| `` `uvm_error `` | `UVM_ERROR` | Display + Count | Verification failures, mismatches |
| `` `uvm_fatal `` | `UVM_FATAL` | Display + Exit | Unrecoverable errors (missing config, null handles) |

### Usage

```systemverilog
// Info — most common, controlled by verbosity
`uvm_info("DRIVER", "Driving transaction to DUT", UVM_MEDIUM)
`uvm_info("DRIVER", $sformatf("Data: 0x%08h", txn.data), UVM_HIGH)

// Warning — something unusual but recoverable
`uvm_warning("MON", "Received unexpected response type")

// Error — a verification failure
`uvm_error("SCB", $sformatf("Mismatch: expected 0x%02h, got 0x%02h", exp, act))

// Fatal — simulation cannot continue
`uvm_fatal("CFG", "Virtual interface not found in config_db")
```

### Message Format

Each macro produces output in this format:

```
UVM_INFO driver.sv(42) @ 1500ns: uvm_test_top.env.agent.driver [DRIVER] Driving transaction to DUT
│        │               │        │                                │       │
│        │               │        │                                │       └─ Message text
│        │               │        │                                └─ Message ID (tag)
│        │               │        └─ Component hierarchical path
│        │               └─ Simulation time
│        └─ Source file and line number
└─ Severity level
```

## Verbosity Levels

The `uvm_info` macro takes a third argument — the **verbosity level**. Messages are only displayed if their verbosity is at or below the component's verbosity threshold.

| Verbosity Level | Value | Typical Use |
|-----------------|-------|-------------|
| `UVM_NONE` | 0 | Always displayed (critical messages) |
| `UVM_LOW` | 100 | Important summaries |
| `UVM_MEDIUM` | 200 | Standard operation messages (default threshold) |
| `UVM_HIGH` | 300 | Detailed debug information |
| `UVM_FULL` | 400 | Exhaustive debug output |
| `UVM_DEBUG` | 500 | Developer-level debugging |

### Examples

```systemverilog
// Always shown (below any reasonable threshold)
`uvm_info("TEST", "Test starting", UVM_NONE)

// Shown at default verbosity
`uvm_info("TEST", "Sequence started", UVM_MEDIUM)

// Only shown when verbosity is raised to HIGH or above
`uvm_info("DRV", $sformatf("Driving: %s", txn.convert2string()), UVM_HIGH)

// Only shown in deep debug mode
`uvm_info("DRV", $sformatf("Signal values: data=0x%h valid=%b", data, valid), UVM_DEBUG)
```

### Setting Verbosity

**From the command line** (most common):

```bash
# Set global verbosity
./simv +UVM_VERBOSITY=UVM_HIGH

# Set per-component verbosity
./simv +uvm_set_verbosity=uvm_test_top.env.agent.driver,DRIVER,UVM_DEBUG,run
```

**From code:**

```systemverilog
// Set verbosity for a specific component
env.agent.driver.set_report_verbosity_level(UVM_HIGH);

// Set verbosity for all components
uvm_top.set_report_verbosity_level_hier(UVM_HIGH);
```

## Error Handling

### Maximum Error Count

By default, UVM stops simulation after a configurable number of errors:

```systemverilog
// In the test's build_phase:
function void build_phase(uvm_phase phase);
  super.build_phase(phase);
  // Stop after 10 errors (default is implementation-dependent)
  set_report_max_quit_count(10);
endfunction
```

From the command line:

```bash
./simv +UVM_MAX_QUIT_COUNT=5
```

### Converting Severity Levels

You can change how a specific message ID is handled:

```systemverilog
// Promote a specific warning to an error
set_report_severity_id_override(UVM_WARNING, "TIMEOUT", UVM_ERROR);

// Demote a specific error to a warning (e.g., a known issue)
set_report_severity_id_override(UVM_ERROR, "KNOWN_BUG_123", UVM_WARNING);
```

### Suppressing Messages

```systemverilog
// Suppress all messages with a specific ID
set_report_severity_id_action(UVM_WARNING, "EXPECTED_WARN", UVM_NO_ACTION);

// Or from the command line:
// +uvm_set_action=*,EXPECTED_WARN,UVM_WARNING,UVM_NO_ACTION
```

## Message Actions

Each message can trigger a combination of actions:

| Action | Description |
|--------|-------------|
| `UVM_NO_ACTION` | Do nothing |
| `UVM_DISPLAY` | Print to stdout |
| `UVM_LOG` | Write to a log file |
| `UVM_COUNT` | Increment error count (contributes to quit count) |
| `UVM_EXIT` | End simulation immediately |
| `UVM_CALL_HOOK` | Call a user-defined hook function |
| `UVM_RM_RECORD` | Record to a transaction database |

### Default Actions by Severity

| Severity | Default Actions |
|----------|----------------|
| `UVM_INFO` | `UVM_DISPLAY` |
| `UVM_WARNING` | `UVM_DISPLAY` |
| `UVM_ERROR` | `UVM_DISPLAY \| UVM_COUNT` |
| `UVM_FATAL` | `UVM_DISPLAY \| UVM_EXIT` |

### Customizing Actions

```systemverilog
// Log all errors to a file in addition to displaying
set_report_severity_action(UVM_ERROR, UVM_DISPLAY | UVM_LOG | UVM_COUNT);

// Set up a log file
set_report_default_file(log_file);
```

## Practical Examples

### Scoreboard Reporting

```systemverilog
class my_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(my_scoreboard)
  
  int pass_count = 0;
  int fail_count = 0;
  int total_count = 0;
  
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
  
  function void check_result(my_transaction expected, my_transaction actual);
    total_count++;
    
    if (expected.compare(actual)) begin
      pass_count++;
      `uvm_info("SCB", $sformatf("PASS [%0d]: %s", total_count, actual.convert2string()), UVM_HIGH)
    end else begin
      fail_count++;
      `uvm_error("SCB", $sformatf("FAIL [%0d]: Expected: %s  Got: %s",
                                   total_count, expected.convert2string(), actual.convert2string()))
    end
  endfunction
  
  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    
    `uvm_info("SCB", "========================================", UVM_NONE)
    `uvm_info("SCB", $sformatf("  Total Transactions: %0d", total_count), UVM_NONE)
    `uvm_info("SCB", $sformatf("  Passed:             %0d", pass_count), UVM_NONE)
    `uvm_info("SCB", $sformatf("  Failed:             %0d", fail_count), UVM_NONE)
    `uvm_info("SCB", "========================================", UVM_NONE)
    
    if (fail_count > 0)
      `uvm_error("SCB", "*** TEST FAILED ***")
    else
      `uvm_info("SCB", "*** TEST PASSED ***", UVM_NONE)
  endfunction
endclass
```

### Driver Debug Messages

```systemverilog
class my_driver extends uvm_driver #(my_transaction);
  task run_phase(uvm_phase phase);
    my_transaction txn;
    
    forever begin
      seq_item_port.get_next_item(txn);
      
      `uvm_info("DRV", $sformatf("Received transaction: %s", txn.convert2string()), UVM_HIGH)
      
      drive_transaction(txn);
      
      `uvm_info("DRV", "Transaction driven successfully", UVM_FULL)
      
      seq_item_port.item_done();
    end
  endtask
endclass
```

### Test Phase Reporting

```systemverilog
class my_test extends uvm_test;
  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    
    `uvm_info("TEST", "============ Test Starting ============", UVM_NONE)
    
    seq = my_sequence::type_id::create("seq");
    seq.start(env.agent.sequencer);
    
    `uvm_info("TEST", "============ Test Complete ============", UVM_NONE)
    
    phase.drop_objection(this);
  endtask
endclass
```

## Command-Line Verbosity Control

```bash
# Run with minimal output
./simv +UVM_VERBOSITY=UVM_LOW

# Run with full debug output
./simv +UVM_VERBOSITY=UVM_DEBUG

# Set verbosity for specific components
./simv +UVM_VERBOSITY=UVM_LOW \
       +uvm_set_verbosity=uvm_test_top.env.agent.driver,*,UVM_DEBUG,run

# Set specific test
./simv +UVM_TESTNAME=my_test

# Combine options
./simv +UVM_TESTNAME=stress_test +UVM_VERBOSITY=UVM_HIGH +UVM_MAX_QUIT_COUNT=100
```

## Summary

| Feature | Description |
|---------|-------------|
| `` `uvm_info `` | Informational messages with verbosity control |
| `` `uvm_warning `` | Non-fatal issues |
| `` `uvm_error `` | Verification failures (counted) |
| `` `uvm_fatal `` | Unrecoverable errors (exits) |
| Verbosity levels | `UVM_NONE` through `UVM_DEBUG` |
| `+UVM_VERBOSITY` | Command-line verbosity control |
| `set_report_severity_id_override` | Change how specific messages are handled |
| `report_phase` | Print final summary statistics |

---

[← Previous: Chapter 8 — Configuration Database](08_config_db.md) | [Back to README →](../README.md)
