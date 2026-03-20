# Chapter 2 -- UVM Intermediate

## 2.1 Sequences and Sequence Items

Sequences are the primary mechanism for generating stimulus in UVM. They decouple
**what** to send from **how** to send it.

### Architecture

```
┌──────────────┐     ┌──────────────┐     ┌──────────┐     ┌─────┐
│   Sequence   │────▶│  Sequencer   │────▶│  Driver  │────▶│ DUT │
│  (stimulus)  │     │ (arbitrator) │     │ (pin-    │     │     │
│              │◀────│              │◀────│  wiggle) │     │     │
└──────────────┘     └──────────────┘     └──────────┘     └─────┘
    body()          seq_item_port /           get /
    start_item()    seq_item_export          item_done()
    finish_item()
```

### Basic Sequence

```systemverilog
class write_sequence extends uvm_sequence #(my_transaction);
  `uvm_object_utils(write_sequence)

  rand int unsigned num_txns;
  constraint c_num { num_txns inside {[5:20]}; }

  function new(string name = "write_sequence");
    super.new(name);
  endfunction

  virtual task body();
    my_transaction tx;

    repeat(num_txns) begin
      tx = my_transaction::type_id::create("tx");
      start_item(tx);
      if (!tx.randomize() with { write == 1; })
        `uvm_fatal("SEQ", "Randomization failed")
      finish_item(tx);
    end
  endtask
endclass
```

### Sequence Execution Flow

The `start_item` / `finish_item` handshake coordinates with the driver:

```
Sequence                    Sequencer                   Driver
   │                            │                          │
   │── start_item(tx) ─────────▶│                          │
   │                            │    (waits for grant)     │
   │                            │◀── get_next_item() ──────│
   │◀── (grant returned) ──────│                          │
   │                            │                          │
   │   randomize tx             │                          │
   │                            │                          │
   │── finish_item(tx) ────────▶│── (send tx) ────────────▶│
   │                            │                          │  drive tx
   │                            │◀── item_done() ──────────│
   │◀── (returns) ─────────────│                          │
```

### Sequence Variations

**Sequence with response:**

```systemverilog
virtual task body();
  my_transaction tx;
  tx = my_transaction::type_id::create("tx");

  start_item(tx);
  tx.randomize();
  finish_item(tx);

  // Retrieve the response from the driver
  get_response(rsp);
  `uvm_info("SEQ", $sformatf("Response: %s", rsp.convert2string()), UVM_MEDIUM)
endtask
```

**Sequence of sequences (hierarchical):**

```systemverilog
class full_test_sequence extends uvm_sequence #(my_transaction);
  `uvm_object_utils(full_test_sequence)

  function new(string name = "full_test_sequence");
    super.new(name);
  endfunction

  virtual task body();
    write_sequence wr_seq;
    read_sequence  rd_seq;
    reset_sequence rst_seq;

    // Execute sub-sequences in order
    rst_seq = reset_sequence::type_id::create("rst_seq");
    rst_seq.start(m_sequencer);

    wr_seq = write_sequence::type_id::create("wr_seq");
    wr_seq.start(m_sequencer);

    rd_seq = read_sequence::type_id::create("rd_seq");
    rd_seq.start(m_sequencer);
  endtask
endclass
```

### The `uvm_do` Family of Macros

UVM provides convenience macros that combine `create`, `start_item`, `randomize`, and
`finish_item`:

```systemverilog
virtual task body();
  // Simple randomization
  `uvm_do(req)

  // Randomization with inline constraints
  `uvm_do_with(req, { addr == 8'hAB; write == 1; })

  // On a specific sequencer
  `uvm_do_on(req, target_sequencer)

  // With priority
  `uvm_do_pri(req, 100)
endtask
```

> **Recommendation:** Prefer explicit `start_item` / `finish_item` over macros for better
> readability and debuggability.

---

## 2.2 The UVM Configuration Database

`uvm_config_db` is a global, hierarchically-scoped database for passing configuration
information between components without hard-coding dependencies.

### Setting Values

```systemverilog
// In the top module -- set a virtual interface
uvm_config_db#(virtual my_if)::set(null, "uvm_test_top.env.agt.*", "vif", dut_if);

// In the test -- set agent mode
uvm_config_db#(uvm_active_passive_enum)::set(this, "env.agt", "is_active", UVM_ACTIVE);

// In the test -- set an integer parameter
uvm_config_db#(int)::set(this, "env.agt.drv", "max_retries", 5);
```

### Getting Values

```systemverilog
class my_driver extends uvm_driver #(my_transaction);
  virtual my_if vif;
  int max_retries = 3;

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    if (!uvm_config_db#(virtual my_if)::get(this, "", "vif", vif))
      `uvm_fatal("DRV", "Failed to get virtual interface")

    // Optional config -- use default if not set
    void'(uvm_config_db#(int)::get(this, "", "max_retries", max_retries));
  endfunction
endclass
```

### Hierarchical Scoping

The `set` call uses the **context** (first argument) and a **path** (second argument) to
determine scope:

```systemverilog
// Available to ALL components
uvm_config_db#(int)::set(null, "*", "timeout", 1000);

// Available only to env.agt and its children
uvm_config_db#(int)::set(this, "env.agt*", "burst_len", 4);

// Available only to a specific component
uvm_config_db#(int)::set(this, "env.agt.drv", "delay", 10);
```

### Configuration Objects

For complex configurations, use a configuration object:

```systemverilog
class my_agent_config extends uvm_object;
  `uvm_object_utils(my_agent_config)

  uvm_active_passive_enum is_active = UVM_ACTIVE;
  int unsigned             num_lanes = 4;
  bit                      coverage_enable = 1;
  virtual my_if            vif;

  function new(string name = "my_agent_config");
    super.new(name);
  endfunction
endclass

// In the test
class my_test extends uvm_test;
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    my_agent_config cfg = my_agent_config::type_id::create("cfg");
    cfg.is_active = UVM_ACTIVE;
    cfg.num_lanes = 8;

    if (!uvm_config_db#(virtual my_if)::get(this, "", "vif", cfg.vif))
      `uvm_fatal("TEST", "No interface")

    uvm_config_db#(my_agent_config)::set(this, "env.agt", "cfg", cfg);

    env = my_env::type_id::create("env", this);
  endfunction
endclass

// In the agent
class my_agent extends uvm_agent;
  my_agent_config cfg;

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    if (!uvm_config_db#(my_agent_config)::get(this, "", "cfg", cfg))
      `uvm_fatal("AGT", "No config")

    // Use cfg.is_active instead of get_is_active()
    if (cfg.is_active == UVM_ACTIVE) begin
      drv = my_driver::type_id::create("drv", this);
      sqr = my_sequencer::type_id::create("sqr", this);
    end
    mon = my_monitor::type_id::create("mon", this);
  endfunction
endclass
```

---

## 2.3 UVM Reporting and Messaging

UVM has a built-in reporting mechanism with four severity levels:

### Severity Levels

| Macro | Severity | Default Action |
|-------|----------|----------------|
| `` `uvm_info `` | Info | Display (filtered by verbosity) |
| `` `uvm_warning `` | Warning | Display |
| `` `uvm_error `` | Error | Display, count toward `max_quit_count` |
| `` `uvm_fatal `` | Fatal | Display, then exit immediately |

### Usage

```systemverilog
// uvm_info takes three arguments: ID, message, verbosity
`uvm_info("DRIVER", "Transaction sent", UVM_MEDIUM)
`uvm_info("DRIVER", $sformatf("Addr=0x%0h Data=0x%0h", tx.addr, tx.data), UVM_HIGH)

// uvm_warning and uvm_error take two arguments: ID, message
`uvm_warning("MON", "Unexpected protocol violation")
`uvm_error("SB", $sformatf("Data mismatch: exp=0x%0h act=0x%0h", exp, act))

// uvm_fatal exits simulation immediately
`uvm_fatal("CFG", "Configuration object not found")
```

### Verbosity Levels

```
UVM_NONE   = 0     Always printed
UVM_LOW    = 100   Low detail
UVM_MEDIUM = 200   Normal detail (default threshold)
UVM_HIGH   = 300   Detailed debug information
UVM_FULL   = 400   Everything
UVM_DEBUG  = 500   Maximum detail
```

### Controlling Verbosity

```bash
# From command line
+UVM_VERBOSITY=UVM_HIGH

# Per component (from command line)
+uvm_set_verbosity=uvm_test_top.env.agt.drv,DRIVER,UVM_DEBUG,run
```

```systemverilog
// Programmatically in code
env.agt.drv.set_report_verbosity_level(UVM_HIGH);

// Change action for a specific ID
env.agt.drv.set_report_severity_action(UVM_ERROR, UVM_DISPLAY | UVM_COUNT | UVM_STOP);
```

### Setting Maximum Errors

```systemverilog
function void end_of_elaboration_phase(uvm_phase phase);
  super.end_of_elaboration_phase(phase);
  // Stop simulation after 10 errors
  set_report_max_quit_count(10);
endfunction
```

---

## 2.4 UVM Scoreboard Patterns

### Pattern 1: In-Order Comparison

```systemverilog
class inorder_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(inorder_scoreboard)

  uvm_tlm_analysis_fifo #(my_transaction) expected_fifo;
  uvm_tlm_analysis_fifo #(my_transaction) actual_fifo;

  int match_count   = 0;
  int mismatch_count = 0;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

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

      if (exp_tx.compare(act_tx)) begin
        match_count++;
        `uvm_info("SB", $sformatf("MATCH #%0d: %s", match_count,
                  exp_tx.convert2string()), UVM_HIGH)
      end else begin
        mismatch_count++;
        `uvm_error("SB", $sformatf("MISMATCH #%0d:\n  EXP: %s\n  ACT: %s",
                   mismatch_count, exp_tx.convert2string(), act_tx.convert2string()))
      end
    end
  endtask

  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info("SB", $sformatf("Matches: %0d  Mismatches: %0d",
              match_count, mismatch_count), UVM_LOW)
  endfunction
endclass
```

### Pattern 2: Prediction-Based Scoreboard

```systemverilog
class predictor_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(predictor_scoreboard)

  uvm_analysis_imp #(my_transaction, predictor_scoreboard) input_export;

  // Reference model state
  bit [31:0] memory [bit [7:0]];

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    input_export = new("input_export", this);
  endfunction

  function void write(my_transaction tx);
    if (tx.write) begin
      // Write -- update reference model
      memory[tx.addr] = tx.data;
      `uvm_info("SB", $sformatf("WRITE: mem[0x%02h] = 0x%08h",
                tx.addr, tx.data), UVM_HIGH)
    end else begin
      // Read -- compare with reference model
      if (memory.exists(tx.addr)) begin
        if (memory[tx.addr] !== tx.data)
          `uvm_error("SB", $sformatf("READ MISMATCH @ 0x%02h: exp=0x%08h act=0x%08h",
                     tx.addr, memory[tx.addr], tx.data))
        else
          `uvm_info("SB", $sformatf("READ MATCH @ 0x%02h = 0x%08h",
                    tx.addr, tx.data), UVM_HIGH)
      end else begin
        `uvm_warning("SB", $sformatf("READ from uninitialized addr 0x%02h", tx.addr))
      end
    end
  endfunction
endclass
```

---

## 2.5 Coverage Collection

### Functional Coverage in UVM

```systemverilog
class my_coverage extends uvm_subscriber #(my_transaction);
  `uvm_component_utils(my_coverage)

  my_transaction tx;

  covergroup cg;
    addr_cp: coverpoint tx.addr {
      bins low    = {[0:63]};
      bins mid    = {[64:191]};
      bins high   = {[192:255]};
    }

    write_cp: coverpoint tx.write {
      bins read  = {0};
      bins write = {1};
    }

    addr_x_write: cross addr_cp, write_cp;
  endgroup

  function new(string name, uvm_component parent);
    super.new(name, parent);
    cg = new();
  endfunction

  function void write(my_transaction t);
    tx = t;
    cg.sample();
  endfunction

  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info("COV", $sformatf("Functional coverage: %.2f%%",
              cg.get_inst_coverage()), UVM_LOW)
  endfunction
endclass
```

### Connecting Coverage to the Environment

```systemverilog
class my_env extends uvm_env;
  my_agent    agt;
  my_coverage cov;

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    agt = my_agent::type_id::create("agt", this);
    cov = my_coverage::type_id::create("cov", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    agt.mon.ap.connect(cov.analysis_export);
  endfunction
endclass
```

---

## 2.6 Command-Line Processing

UVM supports several standard command-line plusargs:

| Plusarg | Purpose | Example |
|---------|---------|---------|
| `+UVM_TESTNAME` | Select test to run | `+UVM_TESTNAME=my_test` |
| `+UVM_VERBOSITY` | Set global verbosity | `+UVM_VERBOSITY=UVM_HIGH` |
| `+UVM_MAX_QUIT_COUNT` | Max errors before quit | `+UVM_MAX_QUIT_COUNT=10` |
| `+UVM_TIMEOUT` | Phase timeout | `+UVM_TIMEOUT=1000000` |
| `+uvm_set_config_int` | Set int config | `+uvm_set_config_int=*,num_txns,100` |
| `+uvm_set_config_string` | Set string config | `+uvm_set_config_string=*,mode,fast` |
| `+uvm_set_type_override` | Factory override | `+uvm_set_type_override=base_drv,ext_drv` |

### Custom Plusargs

```systemverilog
class my_test extends uvm_test;
  int num_iterations;

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    if ($value$plusargs("NUM_ITER=%d", num_iterations))
      `uvm_info("TEST", $sformatf("Running %0d iterations", num_iterations), UVM_LOW)
    else
      num_iterations = 100;  // default
  endfunction
endclass
```

---

**Previous:** [Chapter 1 -- UVM Basics](01_uvm_basics.md) |
**Next:** [Chapter 3 -- UVM Advanced](03_uvm_advanced.md)
