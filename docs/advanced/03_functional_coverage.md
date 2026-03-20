# Advanced Chapter 3: Functional Coverage

## What Is Functional Coverage?

Functional coverage measures **which features and scenarios have been exercised** during simulation. Unlike code coverage (which is automatically extracted from RTL), functional coverage is defined by the verification engineer based on the verification plan.

```
Verification Plan        →  Covergroups        →  Coverage Database
"Test all opcodes"       →  coverpoint opcode   →  85% covered
"Test boundary addrs"    →  coverpoint addr     →  100% covered
"Test addr x opcode"     →  cross addr, opcode  →  72% covered
```

## Covergroups in UVM

### Basic Covergroup

```systemverilog
class alu_coverage extends uvm_subscriber #(alu_transaction);
  `uvm_component_utils(alu_coverage)

  alu_transaction tx;

  covergroup alu_cg;
    option.per_instance = 1;

    opcode_cp: coverpoint tx.opcode {
      bins add  = {ADD};
      bins sub  = {SUB};
      bins mul  = {MUL};
      bins div  = {DIV};
      bins and_op = {AND};
      bins or_op  = {OR};
      bins xor_op = {XOR};
      bins shl  = {SHL};
    }

    operand_a_cp: coverpoint tx.operand_a {
      bins zero     = {0};
      bins small    = {[1:255]};
      bins medium   = {[256:65535]};
      bins large    = {[65536:$]};
      bins max_val  = {{32{1'b1}}};
    }

    operand_b_cp: coverpoint tx.operand_b {
      bins zero     = {0};
      bins small    = {[1:255]};
      bins medium   = {[256:65535]};
      bins large    = {[65536:$]};
      bins max_val  = {{32{1'b1}}};
    }

    // Cross coverage: every opcode with every operand range
    op_x_a: cross opcode_cp, operand_a_cp;
    op_x_b: cross opcode_cp, operand_b_cp;
  endgroup

  function new(string name = "alu_coverage", uvm_component parent = null);
    super.new(name, parent);
    alu_cg = new();
  endfunction

  function void write(alu_transaction t);
    tx = t;
    alu_cg.sample();
  endfunction

  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info("COV", $sformatf("ALU Coverage: %.1f%%", alu_cg.get_inst_coverage()), UVM_LOW)
  endfunction
endclass
```

## Coverpoint Features

### Bins

```systemverilog
coverpoint addr {
  // Explicit bins
  bins reg_space   = {[0:255]};
  bins mem_space   = {[256:4095]};
  bins io_space    = {[4096:8191]};

  // Auto bins (UVM creates one bin per value)
  bins all_values[] = {[0:255]};

  // Wildcard bins
  wildcard bins aligned_4   = {32'b????_????_????_????_????_????_????_00??};

  // Illegal bins (if hit, generates an error)
  illegal_bins reserved = {[8192:$]};

  // Ignore bins (excluded from coverage calculation)
  ignore_bins debug_only = {32'hFFFF_FFFF};
}
```

### Transitions

```systemverilog
coverpoint state {
  bins idle_to_active = (IDLE => ACTIVE);
  bins active_to_done = (ACTIVE => DONE);
  bins done_to_idle   = (DONE => IDLE);
  bins full_cycle     = (IDLE => ACTIVE => DONE => IDLE);

  // Consecutive repetitions
  bins idle_held      = (IDLE [*3]);       // IDLE for 3 consecutive samples
  bins any_to_error   = (IDLE, ACTIVE, DONE => ERROR);
}
```

### Conditional Coverage

```systemverilog
covergroup cg @(posedge clk);
  // Only sample when valid is high
  coverpoint data iff (valid) {
    bins low  = {[0:127]};
    bins high = {[128:255]};
  }
endgroup
```

## Cross Coverage

Cross coverage captures **combinations** of coverpoints.

```systemverilog
covergroup bus_cg;
  cmd_cp: coverpoint tx.cmd {
    bins read  = {READ};
    bins write = {WRITE};
  }

  size_cp: coverpoint tx.size {
    bins byte_  = {1};
    bins half   = {2};
    bins word   = {4};
  }

  addr_cp: coverpoint tx.addr[31:28] {
    bins sram  = {4'h0};
    bins flash = {4'h1};
    bins periph = {4'h4};
  }

  // Full cross: cmd x size x addr = 2 * 3 * 3 = 18 bins
  cmd_size_addr: cross cmd_cp, size_cp, addr_cp;

  // Filtered cross: exclude certain combinations
  cmd_size: cross cmd_cp, size_cp {
    ignore_bins no_byte_write = binsof(cmd_cp.write) && binsof(size_cp.byte_);
  }
endgroup
```

## Integration with UVM Components

### Coverage in a Subscriber

```systemverilog
class pkt_coverage extends uvm_subscriber #(ethernet_packet);
  `uvm_component_utils(pkt_coverage)

  ethernet_packet pkt;

  covergroup pkt_cg;
    pkt_type_cp: coverpoint pkt.pkt_type;
    pkt_len_cp:  coverpoint pkt.length {
      bins short_  = {[64:127]};
      bins medium  = {[128:511]};
      bins long_   = {[512:1518]};
      bins jumbo   = {[1519:9000]};
    }
    vlan_cp: coverpoint pkt.has_vlan;
    type_x_len: cross pkt_type_cp, pkt_len_cp;
  endgroup

  function new(string name, uvm_component parent);
    super.new(name, parent);
    pkt_cg = new();
  endfunction

  function void write(ethernet_packet t);
    pkt = t;
    pkt_cg.sample();
  endfunction
endclass
```

### Connection in Environment

```systemverilog
class my_env extends uvm_env;
  pkt_coverage cov;
  my_agent     agent;

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    agent = my_agent::type_id::create("agent", this);
    cov   = pkt_coverage::type_id::create("cov", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    agent.mon.ap.connect(cov.analysis_export);
  endfunction
endclass
```

## Coverage-Driven Verification Flow

```
1. Define verification plan (features, scenarios, corner cases)
       │
2. Translate plan into covergroups
       │
3. Run constrained-random tests
       │
4. Collect coverage
       │
5. Analyze coverage holes
       │
       ├── Coverage < target? → Add constraints or directed sequences → Go to 3
       │
       └── Coverage ≥ target? → Sign off
```

### Checking Coverage in Tests

```systemverilog
function void report_phase(uvm_phase phase);
  real cov;
  super.report_phase(phase);
  cov = $get_coverage();
  if (cov < 95.0)
    `uvm_warning("COV", $sformatf("Total coverage only %.1f%% — below 95%% target", cov))
  else
    `uvm_info("COV", $sformatf("Coverage target met: %.1f%%", cov), UVM_LOW)
endfunction
```

## Advanced Techniques

### Coverage Callbacks

```systemverilog
covergroup adaptive_cg with function sample(bit [7:0] opcode, bit [31:0] addr);
  op_cp: coverpoint opcode;
  addr_cp: coverpoint addr[15:0] {
    bins low  = {[0:16'h00FF]};
    bins high = {[16'h0100:16'hFFFF]};
  }
endgroup

// Sample from multiple places
adaptive_cg cg = new();
cg.sample(tx.opcode, tx.addr);
```

### Coverage Merging Across Tests

Most simulators support merging coverage databases from multiple test runs:

```bash
# VCS
urg -dir simv.vdb test1.vdb test2.vdb -report merged_report

# Xcelium
imc -load cov_work/scope/test1 -load cov_work/scope/test2 -report merged
```

### Temporal Coverage (Assertion-Based)

```systemverilog
// Cover that a specific protocol sequence occurs
cover property (@(posedge clk)
  req ##[1:5] gnt ##1 !req ##1 !gnt
);

// Cover interrupt latency ranges
covergroup irq_latency_cg;
  latency_cp: coverpoint irq_latency {
    bins fast   = {[1:5]};
    bins medium = {[6:20]};
    bins slow   = {[21:100]};
  }
endgroup
```

## Best Practices

1. **Derive covergroups from the verification plan** — every feature should map to a coverpoint.
2. **Use cross coverage judiciously** — large crosses explode combinatorially; use `ignore_bins` to prune.
3. **Set meaningful bin ranges** — don't just use auto-bins; define ranges that correspond to DUT behavior.
4. **Sample in subscribers** — connect to monitor analysis ports for real DUT behavior.
5. **Track coverage per test** — identify which tests contribute most to coverage.
6. **Target 100% on critical features**, 95%+ overall.

## Next Steps

Continue to [Chapter 4: Callbacks](04_callbacks.md) to learn about extending component behavior.
