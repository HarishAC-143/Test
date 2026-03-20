# Advanced Chapter 6: UVM Patterns and Best Practices

## Testbench Architecture Patterns

### Pattern 1: Configuration Object Pattern

Instead of scattering `uvm_config_db` calls throughout the testbench, centralize configuration in dedicated objects.

```systemverilog
class agent_config extends uvm_object;
  `uvm_object_utils(agent_config)

  uvm_active_passive_enum is_active = UVM_ACTIVE;
  bit enable_coverage = 1;
  bit enable_checks   = 1;
  int num_lanes       = 1;
  virtual my_if vif;

  function new(string name = "agent_config");
    super.new(name);
  endfunction
endclass

class env_config extends uvm_object;
  `uvm_object_utils(env_config)

  int num_agents = 1;
  bit enable_scoreboard = 1;
  agent_config agent_cfgs[];

  function new(string name = "env_config");
    super.new(name);
  endfunction
endclass
```

Usage:
```systemverilog
class my_test extends uvm_test;
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env_config ecfg = env_config::type_id::create("ecfg");
    ecfg.num_agents = 2;
    ecfg.agent_cfgs = new[2];
    foreach (ecfg.agent_cfgs[i]) begin
      ecfg.agent_cfgs[i] = agent_config::type_id::create($sformatf("acfg_%0d", i));
      ecfg.agent_cfgs[i].is_active = UVM_ACTIVE;
    end
    uvm_config_db #(env_config)::set(this, "env", "cfg", ecfg);
    env = my_env::type_id::create("env", this);
  endfunction
endclass
```

### Pattern 2: Base Test Pattern

Create a base test that handles common setup; derive specific tests for different scenarios.

```systemverilog
class base_test extends uvm_test;
  `uvm_component_utils(base_test)

  my_env env;
  env_config cfg;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    cfg = env_config::type_id::create("cfg");
    configure_env(cfg);
    uvm_config_db #(env_config)::set(this, "env", "cfg", cfg);
    env = my_env::type_id::create("env", this);
  endfunction

  // Override this in derived tests
  virtual function void configure_env(env_config cfg);
    cfg.num_agents = 1;
    cfg.enable_scoreboard = 1;
  endfunction

  function void end_of_elaboration_phase(uvm_phase phase);
    super.end_of_elaboration_phase(phase);
    uvm_top.print_topology();
  endfunction

  function void report_phase(uvm_phase phase);
    uvm_report_server srv = uvm_report_server::get_server();
    super.report_phase(phase);
    if (srv.get_severity_count(UVM_ERROR) > 0 || srv.get_severity_count(UVM_FATAL) > 0)
      `uvm_info("TEST", "*** TEST FAILED ***", UVM_NONE)
    else
      `uvm_info("TEST", "*** TEST PASSED ***", UVM_NONE)
  endfunction
endclass

class stress_test extends base_test;
  `uvm_component_utils(stress_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction

  virtual function void configure_env(env_config cfg);
    cfg.num_agents = 4;
    cfg.enable_scoreboard = 1;
  endfunction

  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    begin
      stress_sequence seq = stress_sequence::type_id::create("seq");
      seq.start(env.agents[0].sqr);
    end
    phase.drop_objection(this);
  endtask
endclass
```

### Pattern 3: Scoreboard with Reference Model

```systemverilog
class ref_model_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(ref_model_scoreboard)

  uvm_tlm_analysis_fifo #(input_txn) input_fifo;
  uvm_tlm_analysis_fifo #(output_txn) output_fifo;

  int match_count, mismatch_count;

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    input_fifo  = new("input_fifo", this);
    output_fifo = new("output_fifo", this);
  endfunction

  task run_phase(uvm_phase phase);
    input_txn  in_tx;
    output_txn out_tx, expected;

    forever begin
      input_fifo.get(in_tx);
      expected = predict(in_tx);  // reference model

      output_fifo.get(out_tx);

      if (out_tx.compare(expected)) begin
        match_count++;
        `uvm_info("SB", "MATCH", UVM_HIGH)
      end else begin
        mismatch_count++;
        `uvm_error("SB", $sformatf("MISMATCH\n  Expected: %s\n  Actual:   %s",
                   expected.convert2string(), out_tx.convert2string()))
      end
    end
  endtask

  function output_txn predict(input_txn in_tx);
    output_txn predicted = output_txn::type_id::create("predicted");
    // behavioral model
    predicted.result = compute(in_tx.operand_a, in_tx.operand_b, in_tx.opcode);
    return predicted;
  endfunction
endclass
```

## Coding Guidelines

### Naming Conventions

| Element | Convention | Example |
|---------|-----------|---------|
| Classes | `snake_case` | `apb_driver`, `mem_transaction` |
| Files | Match class name | `apb_driver.sv` |
| Packages | `<protocol>_pkg` | `apb_pkg` |
| Interfaces | `<protocol>_if` | `apb_if` |
| Instances | Short, descriptive | `drv`, `sqr`, `mon`, `env` |
| Macros/constants | `UPPER_CASE` | `MAX_ADDR`, `NUM_AGENTS` |
| Covergroups | `<feature>_cg` | `addr_cg`, `opcode_cg` |

### Package Organization

```systemverilog
package apb_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  `include "apb_types.sv"
  `include "apb_transaction.sv"
  `include "apb_config.sv"
  `include "apb_driver.sv"
  `include "apb_monitor.sv"
  `include "apb_sequencer.sv"
  `include "apb_agent.sv"
  `include "apb_coverage.sv"
  `include "apb_scoreboard.sv"
  `include "apb_env.sv"
  `include "apb_sequences.sv"
  `include "apb_tests.sv"
endpackage
```

### File Structure

```
project/
├── rtl/
│   └── dut.sv
├── tb/
│   ├── apb_agent/
│   │   ├── apb_pkg.sv
│   │   ├── apb_if.sv
│   │   ├── apb_transaction.sv
│   │   ├── apb_driver.sv
│   │   ├── apb_monitor.sv
│   │   ├── apb_sequencer.sv
│   │   └── apb_agent.sv
│   ├── env/
│   │   ├── env_pkg.sv
│   │   ├── scoreboard.sv
│   │   ├── coverage.sv
│   │   └── env.sv
│   ├── tests/
│   │   ├── test_pkg.sv
│   │   ├── base_test.sv
│   │   └── specific_tests.sv
│   ├── sequences/
│   │   ├── seq_pkg.sv
│   │   └── sequences.sv
│   └── top/
│       └── top.sv
├── sim/
│   ├── Makefile
│   └── filelist.f
└── docs/
    └── verification_plan.md
```

## Common Pitfalls and Solutions

### Pitfall 1: Forgetting to Call `super.build_phase()`

```systemverilog
// WRONG — config_db lookups for is_active won't work
function void build_phase(uvm_phase phase);
  mon = my_monitor::type_id::create("mon", this);
endfunction

// CORRECT
function void build_phase(uvm_phase phase);
  super.build_phase(phase);  // always call super
  mon = my_monitor::type_id::create("mon", this);
endfunction
```

### Pitfall 2: Raising Objections in the Wrong Place

```systemverilog
// WRONG — objections in the driver cause confusion
class my_driver extends uvm_driver #(my_txn);
  task run_phase(uvm_phase phase);
    phase.raise_objection(this);  // Don't do this in a driver
    forever begin
      // ...
    end
    phase.drop_objection(this);   // This is never reached
  endtask
endclass

// CORRECT — raise in the test
class my_test extends uvm_test;
  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    seq.start(env.agent.sqr);
    phase.drop_objection(this);
  endtask
endclass
```

### Pitfall 3: Not Using the Factory

```systemverilog
// WRONG — cannot be overridden
my_driver drv = new("drv", this);

// CORRECT
my_driver drv = my_driver::type_id::create("drv", this);
```

### Pitfall 4: Missing `convert2string()`

Always implement `convert2string()` on transactions for meaningful debug output.

### Pitfall 5: Blocking in Analysis Port `write()`

```systemverilog
// WRONG — write() is a function, cannot consume time
function void write(my_txn tx);
  #10;  // COMPILATION ERROR — no time consumption in functions
endfunction

// CORRECT — use a FIFO if you need to process asynchronously
uvm_tlm_analysis_fifo #(my_txn) fifo;
task run_phase(uvm_phase phase);
  my_txn tx;
  forever begin
    fifo.get(tx);
    // ... time-consuming processing ...
  end
endtask
```

## Reusability Checklist

- [ ] Agent works in both active and passive mode
- [ ] Configuration is passed via config objects, not hardcoded
- [ ] All classes are factory-registered
- [ ] No test-specific logic in the agent
- [ ] Virtual interface is obtained from config_db, not passed as constructor argument
- [ ] Sequences are independent of testbench hierarchy
- [ ] Coverage collector is a separate subscriber
- [ ] Scoreboard uses TLM connections, not hierarchical references

## Performance Tips

1. **Avoid `uvm_field_*` macros** — they generate significant overhead. Implement `do_copy`, `do_compare`, `do_print` manually.
2. **Use `UVM_HIGH` or `UVM_FULL` for frequent messages** — suppress them during regression.
3. **Minimize `uvm_config_db` lookups** — cache the result in a local variable.
4. **Use `type_id::create` only during build** — don't create components during `run_phase`.
5. **Set `option.per_instance = 1`** in covergroups to track per-instance coverage.

## Summary

| Practice | Why |
|----------|-----|
| Configuration objects | Centralized, type-safe configuration |
| Base test pattern | Consistent setup, easy test derivation |
| Package organization | Clean compilation, manageable file structure |
| Factory for everything | Enables overrides and flexibility |
| Objections in tests/sequences | Clean simulation lifetime management |
| `convert2string()` everywhere | Essential for debug |
| Separate coverage subscribers | Reusable, modular coverage collection |

---

This concludes Part 2: Advanced UVM. Continue to the [Practical Examples](../../examples/) for complete, runnable testbenches.
