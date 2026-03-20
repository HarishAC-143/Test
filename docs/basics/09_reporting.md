# Chapter 9: Reporting and Messaging

## Overview

UVM provides a structured messaging system that gives you consistent formatting, severity levels, verbosity filtering, and the ability to redirect or override messages at runtime.

## Message Macros

UVM defines four severity levels:

```systemverilog
`uvm_info   (ID, MSG, VERBOSITY)   // Informational
`uvm_warning(ID, MSG)              // Warning — something unexpected but recoverable
`uvm_error  (ID, MSG)              // Error — a check failure
`uvm_fatal  (ID, MSG)              // Fatal — simulation cannot continue, terminates immediately
```

### Parameters

| Parameter | Description |
|-----------|-------------|
| `ID` | A string tag used for filtering (e.g., `"DRV"`, `"SB"`, `"MON"`) |
| `MSG` | The message text (can use `$sformatf` for formatting) |
| `VERBOSITY` | Only for `uvm_info` — controls whether the message is displayed |

### Example Usage

```systemverilog
class my_driver extends uvm_driver #(my_transaction);
  task run_phase(uvm_phase phase);
    forever begin
      seq_item_port.get_next_item(req);

      `uvm_info("DRV", $sformatf("Driving transaction: %s", req.convert2string()), UVM_MEDIUM)

      if (req.addr > MAX_ADDR)
        `uvm_warning("DRV", $sformatf("Address 0x%h exceeds MAX_ADDR", req.addr))

      drive_transaction(req);

      if (vif.error)
        `uvm_error("DRV", "Bus error detected during drive")

      if (vif.fatal_error) begin
        `uvm_fatal("DRV", "Unrecoverable bus error — aborting simulation")
      end

      seq_item_port.item_done();
    end
  endtask
endclass
```

---

## Verbosity Levels

`uvm_info` messages are filtered by verbosity. A message is displayed only if its verbosity is **less than or equal to** the component's verbosity threshold.

| Level | Value | When to Use |
|-------|-------|-------------|
| `UVM_NONE` | 0 | Always displayed — critical information |
| `UVM_LOW` | 100 | High-level test progress |
| `UVM_MEDIUM` | 200 | Transaction-level detail (default threshold) |
| `UVM_HIGH` | 300 | Detailed protocol activity |
| `UVM_FULL` | 400 | Complete internal state dumps |
| `UVM_DEBUG` | 500 | Everything — maximum detail |

### Default Behavior

By default, the verbosity threshold is `UVM_MEDIUM` (200). Messages with `UVM_HIGH` or above are suppressed.

### Setting Verbosity

```bash
# Command line — set globally
./simv +UVM_VERBOSITY=UVM_HIGH

# Command line — set for specific component
./simv +uvm_set_verbosity=uvm_test_top.env.agent.drv,DRV,UVM_DEBUG,run
```

```systemverilog
// Programmatically — from within a component
set_report_verbosity_level(UVM_HIGH);

// For a specific ID only
set_report_id_verbosity("DRV", UVM_DEBUG);

// From a parent for a child
env.agent.drv.set_report_verbosity_level(UVM_DEBUG);
```

---

## Message Output Format

Default UVM message format:

```
UVM_INFO my_driver.sv(42) @ 1000 ns: uvm_test_top.env.agent.drv [DRV] Driving transaction: WR addr=0x0010 data=0xDEAD
│         │              │           │                             │     │
severity  file(line)     time        component path                ID    message
```

---

## Report Actions

Each severity level has a default **action**:

| Severity | Default Action | Meaning |
|----------|---------------|---------|
| `UVM_INFO` | `UVM_DISPLAY` | Print to stdout |
| `UVM_WARNING` | `UVM_DISPLAY` | Print to stdout |
| `UVM_ERROR` | `UVM_DISPLAY \| UVM_COUNT` | Print and count toward max errors |
| `UVM_FATAL` | `UVM_DISPLAY \| UVM_EXIT` | Print and exit simulation |

### Available Actions

| Action | Effect |
|--------|--------|
| `UVM_NO_ACTION` | Do nothing |
| `UVM_DISPLAY` | Print to stdout |
| `UVM_LOG` | Write to a log file |
| `UVM_COUNT` | Increment error count |
| `UVM_EXIT` | Exit simulation |
| `UVM_CALL_HOOK` | Call the `report_hook()` method |
| `UVM_STOP` | Call `$stop` (enter interactive debug) |

### Customizing Actions

```systemverilog
// Make all warnings also stop simulation for interactive debug
set_report_severity_action(UVM_WARNING, UVM_DISPLAY | UVM_STOP);

// Make a specific error ID non-fatal (remove count)
set_report_severity_id_action(UVM_ERROR, "KNOWN_BUG", UVM_DISPLAY);

// Make UVM_INFO messages also log to file
set_report_severity_action(UVM_INFO, UVM_DISPLAY | UVM_LOG);
```

---

## Max Error Count (Quit Count)

By default, UVM exits after **10 `uvm_error` messages**. You can change this:

```systemverilog
// Programmatically
set_report_max_quit_count(50);

// Or from command line
// ./simv +UVM_MAX_QUIT_COUNT=50
```

---

## Report Servers and Custom Formatting

### Custom Report Server

You can override the default formatting by creating a custom report server:

```systemverilog
class my_report_server extends uvm_report_server;

  virtual function string compose_report_message(
    uvm_report_message report_message,
    string report_object_name = ""
  );
    uvm_severity severity = report_message.get_severity();
    string id       = report_message.get_id();
    string message  = report_message.get_message();
    string filename = report_message.get_filename();
    int    line     = report_message.get_line();
    string sev_str;

    case (severity)
      UVM_INFO:    sev_str = "INFO";
      UVM_WARNING: sev_str = "WARN";
      UVM_ERROR:   sev_str = "ERR ";
      UVM_FATAL:   sev_str = "FATL";
    endcase

    return $sformatf("[%s] %0t | %-20s | %s | %s(%0d)",
                     sev_str, $time, report_object_name, message, filename, line);
  endfunction
endclass

// Install the custom server in the test
class my_test extends uvm_test;
  function void start_of_simulation_phase(uvm_phase phase);
    my_report_server srv = new();
    uvm_report_server::set_server(srv);
  endfunction
endclass
```

Output becomes:

```
[INFO] 1000 | env.agent.drv        | Driving transaction: WR addr=0x0010 | my_driver.sv(42)
```

---

## Report Catchers (Message Filtering)

A **report catcher** intercepts messages before they are processed. You can use it to:
- Demote errors to warnings
- Suppress known messages
- Transform message text

```systemverilog
class my_catcher extends uvm_report_catcher;
  `uvm_object_utils(my_catcher)

  function new(string name = "my_catcher");
    super.new(name);
  endfunction

  function action_e catch();
    // Demote a known, non-critical error to a warning
    if (get_severity() == UVM_ERROR && get_id() == "KNOWN_ISSUE") begin
      set_severity(UVM_WARNING);
      set_message({"[Demoted] ", get_message()});
      return THROW;  // continue processing with modified severity
    end

    // Suppress noisy info messages
    if (get_severity() == UVM_INFO && get_id() == "NOISY_MSG") begin
      return CAUGHT;  // swallow the message entirely
    end

    return THROW;  // let all other messages through
  endfunction
endclass

// Install the catcher
class my_test extends uvm_test;
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    begin
      my_catcher catcher = new("catcher");
      uvm_report_cb::add(null, catcher);  // add to all components
    end
  endfunction
endclass
```

---

## Logging to Files

```systemverilog
// In start_of_simulation_phase or build_phase:
UVM_FILE log_file;
log_file = $fopen("driver.log", "w");
set_report_severity_file(UVM_INFO, log_file);
set_report_severity_action(UVM_INFO, UVM_DISPLAY | UVM_LOG);
```

---

## Useful Command-Line Plusargs

| Plusarg | Effect |
|---------|--------|
| `+UVM_VERBOSITY=UVM_HIGH` | Set global verbosity |
| `+UVM_MAX_QUIT_COUNT=50` | Change max error count before exit |
| `+UVM_TIMEOUT=1000000,YES` | Set simulation timeout (in time units) |
| `+UVM_TESTNAME=my_test` | Select the test to run |
| `+uvm_set_verbosity=path,id,verbosity,phase` | Set verbosity for specific component/id |
| `+uvm_set_action=path,id,severity,action` | Set action for specific message |

---

## Best Practices

1. **Choose meaningful IDs** — Use short, consistent tags like `"DRV"`, `"MON"`, `"SB"`, `"SEQ"`.
2. **Use `UVM_MEDIUM` for routine transactions** — This is the default threshold.
3. **Use `UVM_LOW` for test milestones** — Start/end of test phases, key results.
4. **Use `UVM_HIGH` for debug detail** — Individual field values, state transitions.
5. **Always use `$sformatf` in the message** — Never put function calls directly as message arguments (they evaluate even if suppressed).
6. **Set `UVM_MAX_QUIT_COUNT`** appropriately — Too low misses related errors; too high floods the log.

---

## Summary

| Feature | Mechanism |
|---------|-----------|
| Severity levels | `uvm_info`, `uvm_warning`, `uvm_error`, `uvm_fatal` |
| Verbosity filtering | `UVM_NONE` through `UVM_DEBUG` |
| Actions | `UVM_DISPLAY`, `UVM_LOG`, `UVM_COUNT`, `UVM_EXIT`, `UVM_STOP` |
| Custom formatting | Override `uvm_report_server` |
| Message filtering | `uvm_report_catcher` |
| Command-line control | `+UVM_VERBOSITY`, `+UVM_MAX_QUIT_COUNT`, etc. |

---

This concludes Part 1: UVM Basics. Continue to [Part 2: Advanced UVM](../advanced/01_virtual_sequences.md).
