# Advanced Chapter 1: Virtual Sequences and Virtual Sequencers

## The Problem

In a real SoC, multiple interfaces operate simultaneously — an AXI master reads memory while a UART transmits data and an interrupt controller signals events. Each interface has its own agent and sequencer, but tests often need to **coordinate stimulus across multiple agents**.

A regular sequence runs on a single sequencer. A **virtual sequence** orchestrates multiple sub-sequences across different sequencers.

## Architecture

```
                    uvm_test
                       │
                    uvm_env
                   /    |    \
           axi_agent  uart_agent  irq_agent
           /  |  \      / | \      / | \
         drv sqr mon  drv sqr mon  drv sqr mon
                       
          ▲            ▲            ▲
          │            │            │
    ┌─────┴────────────┴────────────┴─────┐
    │         virtual_sequencer           │
    │  (holds handles to real sequencers)  │
    └─────────────────┬───────────────────┘
                      │
              virtual_sequence
    (coordinates sub-sequences across agents)
```

## Virtual Sequencer

The virtual sequencer does not connect to any driver. It simply holds **handles** to real sequencers.

```systemverilog
class soc_virtual_sequencer extends uvm_sequencer;
  `uvm_component_utils(soc_virtual_sequencer)

  axi_sequencer  axi_sqr;
  uart_sequencer uart_sqr;
  irq_sequencer  irq_sqr;

  function new(string name = "soc_virtual_sequencer", uvm_component parent = null);
    super.new(name, parent);
  endfunction
endclass
```

### Connecting in the Environment

```systemverilog
class soc_env extends uvm_env;
  `uvm_component_utils(soc_env)

  axi_agent  axi_agt;
  uart_agent uart_agt;
  irq_agent  irq_agt;
  soc_virtual_sequencer v_sqr;

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    axi_agt  = axi_agent::type_id::create("axi_agt", this);
    uart_agt = uart_agent::type_id::create("uart_agt", this);
    irq_agt  = irq_agent::type_id::create("irq_agt", this);
    v_sqr    = soc_virtual_sequencer::type_id::create("v_sqr", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    v_sqr.axi_sqr  = axi_agt.sqr;
    v_sqr.uart_sqr = uart_agt.sqr;
    v_sqr.irq_sqr  = irq_agt.sqr;
  endfunction
endclass
```

## Virtual Sequence

A virtual sequence runs on the virtual sequencer and starts sub-sequences on the real sequencers.

```systemverilog
class soc_base_virtual_seq extends uvm_sequence;
  `uvm_object_utils(soc_base_virtual_seq)

  `uvm_declare_p_sequencer(soc_virtual_sequencer)

  function new(string name = "soc_base_virtual_seq");
    super.new(name);
  endfunction
endclass
```

### Coordinated Stimulus Example

```systemverilog
class soc_init_seq extends soc_base_virtual_seq;
  `uvm_object_utils(soc_init_seq)

  function new(string name = "soc_init_seq");
    super.new(name);
  endfunction

  task body();
    axi_write_seq   axi_wr;
    uart_config_seq  uart_cfg;
    irq_enable_seq   irq_en;

    `uvm_info("VSEQ", "=== Phase 1: Configure UART via AXI ===", UVM_LOW)
    axi_wr = axi_write_seq::type_id::create("axi_wr");
    axi_wr.start(p_sequencer.axi_sqr);

    `uvm_info("VSEQ", "=== Phase 2: Start UART TX and enable interrupts in parallel ===", UVM_LOW)
    fork
      begin
        uart_cfg = uart_config_seq::type_id::create("uart_cfg");
        uart_cfg.start(p_sequencer.uart_sqr);
      end
      begin
        irq_en = irq_enable_seq::type_id::create("irq_en");
        irq_en.start(p_sequencer.irq_sqr);
      end
    join

    `uvm_info("VSEQ", "=== Initialization Complete ===", UVM_LOW)
  endtask
endclass
```

### Running from the Test

```systemverilog
class soc_init_test extends uvm_test;
  `uvm_component_utils(soc_init_test)

  soc_env env;

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = soc_env::type_id::create("env", this);
  endfunction

  task run_phase(uvm_phase phase);
    soc_init_seq vseq;
    phase.raise_objection(this);
    vseq = soc_init_seq::type_id::create("vseq");
    vseq.start(env.v_sqr);
    phase.drop_objection(this);
  endtask
endclass
```

## Common Patterns

### Pattern 1: Sequential Phases

```systemverilog
task body();
  reset_seq.start(p_sequencer.axi_sqr);     // Phase 1
  config_seq.start(p_sequencer.axi_sqr);     // Phase 2
  traffic_seq.start(p_sequencer.axi_sqr);    // Phase 3
  drain_seq.start(p_sequencer.uart_sqr);     // Phase 4
endtask
```

### Pattern 2: Parallel Traffic with Synchronization

```systemverilog
task body();
  event config_done;

  fork
    begin  // AXI traffic
      axi_config_seq cfg = axi_config_seq::type_id::create("cfg");
      cfg.start(p_sequencer.axi_sqr);
      -> config_done;
      axi_traffic_seq tfc = axi_traffic_seq::type_id::create("tfc");
      tfc.start(p_sequencer.axi_sqr);
    end
    begin  // UART traffic — waits for config
      @(config_done);
      uart_tx_seq tx = uart_tx_seq::type_id::create("tx");
      tx.start(p_sequencer.uart_sqr);
    end
    begin  // IRQ monitoring
      irq_wait_seq irq = irq_wait_seq::type_id::create("irq");
      irq.start(p_sequencer.irq_sqr);
    end
  join
endtask
```

### Pattern 3: Reactive Sequence (Response-Based)

```systemverilog
task body();
  fork
    begin  // Send AXI writes
      repeat(100) begin
        axi_write_seq wr = axi_write_seq::type_id::create("wr");
        wr.start(p_sequencer.axi_sqr);
      end
    end
    begin  // React to interrupts
      forever begin
        irq_wait_seq irq = irq_wait_seq::type_id::create("irq");
        irq.start(p_sequencer.irq_sqr);
        // When interrupt fires, read status register
        axi_read_seq rd = axi_read_seq::type_id::create("rd");
        rd.addr = IRQ_STATUS_REG;
        rd.start(p_sequencer.axi_sqr);
      end
    end
  join_any
  disable fork;
endtask
```

## `uvm_declare_p_sequencer` vs. `m_sequencer`

| Approach | Syntax | When to Use |
|----------|--------|-------------|
| `m_sequencer` | Cast `m_sequencer` to your type | Quick and simple |
| `p_sequencer` | Use `uvm_declare_p_sequencer` macro | Cleaner, avoids repeated casting |

```systemverilog
// With p_sequencer (recommended)
`uvm_declare_p_sequencer(soc_virtual_sequencer)
task body();
  my_seq.start(p_sequencer.axi_sqr);
endtask

// With m_sequencer (manual cast)
task body();
  soc_virtual_sequencer vsqr;
  $cast(vsqr, m_sequencer);
  my_seq.start(vsqr.axi_sqr);
endtask
```

## Best Practices

1. **Always derive from a base virtual sequence** that declares `p_sequencer`.
2. **Use `fork`/`join` for parallel agents** — that's the whole point.
3. **Keep sub-sequences reusable** — they should work independently on their agent.
4. **Don't put protocol-specific logic** in the virtual sequence — delegate to sub-sequences.
5. **Virtual sequencer should not have TLM ports** — it is only a handle container.

## Next Steps

Continue to [Chapter 2: Register Abstraction Layer (RAL)](02_ral.md) to learn about register verification.
