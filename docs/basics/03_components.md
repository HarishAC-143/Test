# Chapter 3: UVM Components Deep Dive

## Component Hierarchy Recap

```
                  uvm_test
                     │
                  uvm_env
                /    │    \
         uvm_agent  scoreboard  coverage
        /    |    \
  driver  sequencer  monitor
```

Each component type has a specific role. This chapter walks through every one with annotated code.

---

## 1. uvm_driver

The driver is the **active stimulus generator** at the signal level. It pulls transactions from the sequencer and wiggles DUT pins accordingly.

```systemverilog
class apb_driver extends uvm_driver #(apb_transaction);
  `uvm_component_utils(apb_driver)

  virtual apb_if vif;

  function new(string name = "apb_driver", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(virtual apb_if)::get(this, "", "vif", vif))
      `uvm_fatal("NOVIF", "APB virtual interface not set")
  endfunction

  task run_phase(uvm_phase phase);
    apb_transaction req;
    forever begin
      seq_item_port.get_next_item(req);      // blocking call to sequencer
      drive_transaction(req);
      seq_item_port.item_done();             // tell sequencer we're finished
    end
  endtask

  task drive_transaction(apb_transaction tx);
    // SETUP phase
    @(posedge vif.pclk);
    vif.psel    <= 1'b1;
    vif.paddr   <= tx.addr;
    vif.pwrite  <= tx.write;
    if (tx.write) vif.pwdata <= tx.data;
    vif.penable <= 1'b0;

    // ACCESS phase
    @(posedge vif.pclk);
    vif.penable <= 1'b1;

    // Wait for PREADY
    @(posedge vif.pclk iff vif.pready);
    if (!tx.write) tx.data = vif.prdata;

    // Return to IDLE
    vif.psel    <= 1'b0;
    vif.penable <= 1'b0;
  endtask
endclass
```

### Key Points

- `seq_item_port` is a built-in TLM port connecting the driver to its sequencer.
- Always call `item_done()` after driving each transaction, or the sequencer will stall.
- The driver should never generate stimulus on its own — all data comes from sequences.

---

## 2. uvm_monitor

The monitor **passively observes** DUT signals and converts them to transactions. It never drives signals.

```systemverilog
class apb_monitor extends uvm_monitor;
  `uvm_component_utils(apb_monitor)

  virtual apb_if vif;
  uvm_analysis_port #(apb_transaction) ap;

  function new(string name = "apb_monitor", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ap = new("ap", this);
    if (!uvm_config_db #(virtual apb_if)::get(this, "", "vif", vif))
      `uvm_fatal("NOVIF", "APB virtual interface not set")
  endfunction

  task run_phase(uvm_phase phase);
    forever begin
      apb_transaction tx;
      @(posedge vif.pclk iff (vif.psel && vif.penable && vif.pready));
      tx = apb_transaction::type_id::create("tx");
      tx.addr  = vif.paddr;
      tx.write = vif.pwrite;
      tx.data  = vif.pwrite ? vif.pwdata : vif.prdata;
      `uvm_info("MON", tx.convert2string(), UVM_HIGH)
      ap.write(tx);  // broadcast to all subscribers
    end
  endtask
endclass
```

### Key Points

- The monitor uses an **analysis port** (`uvm_analysis_port`) to broadcast transactions.
- Multiple subscribers (scoreboard, coverage collector) can connect to the same analysis port.
- The monitor must be present in **both active and passive** agents (it is the only component in a passive agent).

---

## 3. uvm_sequencer

The sequencer **arbitrates** between sequences and delivers transactions to the driver via a TLM FIFO.

For most designs, the default sequencer is sufficient:

```systemverilog
class apb_sequencer extends uvm_sequencer #(apb_transaction);
  `uvm_component_utils(apb_sequencer)

  function new(string name = "apb_sequencer", uvm_component parent = null);
    super.new(name, parent);
  endfunction
endclass
```

### Arbitration Modes

```systemverilog
// In the test or env:
env.agent.sequencer.set_arbitration(UVM_SEQ_ARB_FIFO);        // default
env.agent.sequencer.set_arbitration(UVM_SEQ_ARB_RANDOM);       // random pick
env.agent.sequencer.set_arbitration(UVM_SEQ_ARB_STRICT_FIFO);  // priority-based FIFO
env.agent.sequencer.set_arbitration(UVM_SEQ_ARB_WEIGHTED);     // weighted random
```

---

## 4. uvm_agent

An agent **encapsulates** a driver, sequencer, and monitor for one protocol interface. It supports active and passive modes.

```systemverilog
class apb_agent extends uvm_agent;
  `uvm_component_utils(apb_agent)

  apb_driver    drv;
  apb_sequencer sqr;
  apb_monitor   mon;

  uvm_active_passive_enum is_active = UVM_ACTIVE;

  function new(string name = "apb_agent", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Monitor is always present
    mon = apb_monitor::type_id::create("mon", this);

    // Driver and sequencer only in active mode
    if (is_active == UVM_ACTIVE) begin
      drv = apb_driver::type_id::create("drv", this);
      sqr = apb_sequencer::type_id::create("sqr", this);
    end
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    if (is_active == UVM_ACTIVE) begin
      drv.seq_item_port.connect(sqr.seq_item_export);
    end
  endfunction
endclass
```

### Active vs. Passive

| Mode | Components | Use Case |
|------|-----------|----------|
| **Active** (`UVM_ACTIVE`) | Driver + Sequencer + Monitor | Drives stimulus and monitors |
| **Passive** (`UVM_PASSIVE`) | Monitor only | Observes an interface driven by another source |

---

## 5. uvm_env

The environment is a **container** that groups agents, scoreboards, and other sub-environments.

```systemverilog
class apb_env extends uvm_env;
  `uvm_component_utils(apb_env)

  apb_agent     agent;
  apb_scoreboard scoreboard;
  apb_coverage   coverage;

  function new(string name = "apb_env", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    agent      = apb_agent::type_id::create("agent", this);
    scoreboard = apb_scoreboard::type_id::create("scoreboard", this);
    coverage   = apb_coverage::type_id::create("coverage", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    agent.mon.ap.connect(scoreboard.analysis_export);
    agent.mon.ap.connect(coverage.analysis_export);
  endfunction
endclass
```

### Hierarchical Environments

For SoC-level verification, environments can nest:

```systemverilog
class soc_env extends uvm_env;
  `uvm_component_utils(soc_env)

  apb_env  apb;
  axi_env  axi;
  soc_scoreboard sb;

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    apb = apb_env::type_id::create("apb", this);
    axi = axi_env::type_id::create("axi", this);
    sb  = soc_scoreboard::type_id::create("sb", this);
  endfunction
endclass
```

---

## 6. uvm_scoreboard

The scoreboard **checks DUT correctness** by comparing expected and actual transactions.

```systemverilog
class apb_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(apb_scoreboard)

  uvm_analysis_imp #(apb_transaction, apb_scoreboard) analysis_export;

  // Reference model: simple memory
  bit [31:0] mem [bit [31:0]];
  int pass_count, fail_count;

  function new(string name = "apb_scoreboard", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    analysis_export = new("analysis_export", this);
  endfunction

  function void write(apb_transaction tx);
    if (tx.write) begin
      mem[tx.addr] = tx.data;
      `uvm_info("SB", $sformatf("WRITE addr=0x%08h data=0x%08h", tx.addr, tx.data), UVM_MEDIUM)
    end else begin
      if (mem.exists(tx.addr)) begin
        if (tx.data === mem[tx.addr]) begin
          pass_count++;
          `uvm_info("SB", $sformatf("READ PASS addr=0x%08h data=0x%08h", tx.addr, tx.data), UVM_MEDIUM)
        end else begin
          fail_count++;
          `uvm_error("SB", $sformatf("READ FAIL addr=0x%08h exp=0x%08h got=0x%08h",
                                      tx.addr, mem[tx.addr], tx.data))
        end
      end else begin
        `uvm_warning("SB", $sformatf("READ from uninitialized addr=0x%08h", tx.addr))
      end
    end
  endfunction

  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info("SB", $sformatf("Scoreboard Summary: %0d PASS, %0d FAIL", pass_count, fail_count), UVM_LOW)
    if (fail_count > 0)
      `uvm_error("SB", "TEST FAILED — mismatches detected")
    else
      `uvm_info("SB", "TEST PASSED", UVM_LOW)
  endfunction
endclass
```

### Design Patterns for Scoreboards

1. **In-order comparison** — Use `uvm_tlm_analysis_fifo` with expected and actual streams.
2. **Out-of-order comparison** — Store expected results in an associative array keyed by a unique ID.
3. **Reference model** — Run a behavioral model inside the scoreboard (as shown above).

---

## 7. uvm_test

The test is the **top of the UVM hierarchy**. It configures the environment and starts sequences.

```systemverilog
class apb_base_test extends uvm_test;
  `uvm_component_utils(apb_base_test)

  apb_env env;

  function new(string name = "apb_base_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = apb_env::type_id::create("env", this);
  endfunction

  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    `uvm_info("TEST", "Base test: starting default sequence", UVM_LOW)
    begin
      apb_base_sequence seq = apb_base_sequence::type_id::create("seq");
      seq.start(env.agent.sqr);
    end
    phase.drop_objection(this);
  endtask

  function void end_of_elaboration_phase(uvm_phase phase);
    super.end_of_elaboration_phase(phase);
    uvm_top.print_topology();
  endfunction
endclass

// Derived test with different configuration
class apb_random_test extends apb_base_test;
  `uvm_component_utils(apb_random_test)

  function new(string name = "apb_random_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    `uvm_info("TEST", "Random test: running random sequence", UVM_LOW)
    begin
      apb_random_sequence seq = apb_random_sequence::type_id::create("seq");
      seq.start(env.agent.sqr);
    end
    phase.drop_objection(this);
  endtask
endclass
```

### Selecting Tests at Runtime

Tests are selected via a plusarg — no recompilation needed:

```bash
./simv +UVM_TESTNAME=apb_random_test
```

---

## 8. uvm_subscriber

`uvm_subscriber` is a convenience wrapper around `uvm_component` with a built-in `analysis_export` and an abstract `write()` function. It is ideal for coverage collectors.

```systemverilog
class apb_coverage extends uvm_subscriber #(apb_transaction);
  `uvm_component_utils(apb_coverage)

  apb_transaction tx;

  covergroup apb_cg;
    addr_cp: coverpoint tx.addr {
      bins low    = {[32'h0000_0000 : 32'h0000_00FF]};
      bins mid    = {[32'h0000_0100 : 32'h0000_0FFF]};
      bins high   = {[32'h0000_1000 : 32'hFFFF_FFFF]};
    }
    write_cp: coverpoint tx.write;
    addr_x_write: cross addr_cp, write_cp;
  endgroup

  function new(string name = "apb_coverage", uvm_component parent = null);
    super.new(name, parent);
    apb_cg = new();
  endfunction

  function void write(apb_transaction t);
    tx = t;
    apb_cg.sample();
  endfunction
endclass
```

---

## Summary Table

| Component | Base Class | Registration Macro | Main Responsibility |
|-----------|-----------|-------------------|-------------------|
| Driver | `uvm_driver #(T)` | `uvm_component_utils` | Drives DUT pins per transaction |
| Monitor | `uvm_monitor` | `uvm_component_utils` | Observes DUT pins, broadcasts transactions |
| Sequencer | `uvm_sequencer #(T)` | `uvm_component_utils` | Routes transactions from sequences to driver |
| Agent | `uvm_agent` | `uvm_component_utils` | Groups driver + sequencer + monitor |
| Env | `uvm_env` | `uvm_component_utils` | Groups agents + scoreboards + coverage |
| Test | `uvm_test` | `uvm_component_utils` | Top-level; configures env, starts sequences |
| Scoreboard | `uvm_scoreboard` | `uvm_component_utils` | Checks DUT correctness |
| Subscriber | `uvm_subscriber #(T)` | `uvm_component_utils` | Receives analysis transactions (e.g., coverage) |

## Next Steps

Continue to [Chapter 4: UVM Phases](04_phases.md) to understand simulation lifecycle management.
