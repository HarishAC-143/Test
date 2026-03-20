# Advanced Chapter 2: Register Abstraction Layer (RAL)

## What Is RAL?

The UVM Register Abstraction Layer (RAL) provides a **software model of the DUT's memory-mapped registers**. It abstracts away the bus protocol so that tests can read and write registers by name rather than by address.

```
Test Code:                      Bus Protocol:
  reg_model.CTRL.write(8'hFF);  →  APB Write to 0x0000 with data 0xFF
  reg_model.STATUS.read(data);  →  APB Read from 0x0004
```

## RAL Class Hierarchy

```
uvm_reg_block
  ├── uvm_reg          (register)
  │     └── uvm_reg_field  (bit field within a register)
  ├── uvm_mem          (memory)
  └── uvm_reg_map      (address map)
```

## Building a Register Model

### Step 1: Define Register Fields

```systemverilog
class ctrl_reg extends uvm_reg;
  `uvm_object_utils(ctrl_reg)

  rand uvm_reg_field enable;
  rand uvm_reg_field mode;
  rand uvm_reg_field speed;
  rand uvm_reg_field reserved;

  function new(string name = "ctrl_reg");
    super.new(name, 32, UVM_NO_COVERAGE);  // 32-bit register
  endfunction

  virtual function void build();
    // create(name, size, lsb_pos, access, volatile, reset, has_reset, is_rand, individually_accessible)
    enable = uvm_reg_field::type_id::create("enable");
    enable.configure(this, 1, 0, "RW", 0, 1'h0, 1, 1, 0);
    //                     size=1 bit, LSB=0, Read-Write, reset=0

    mode = uvm_reg_field::type_id::create("mode");
    mode.configure(this, 2, 1, "RW", 0, 2'h0, 1, 1, 0);
    //                   size=2 bits, LSB=1

    speed = uvm_reg_field::type_id::create("speed");
    speed.configure(this, 4, 4, "RW", 0, 4'h5, 1, 1, 0);
    //                    size=4 bits, LSB=4, reset=5

    reserved = uvm_reg_field::type_id::create("reserved");
    reserved.configure(this, 24, 8, "RO", 0, 24'h0, 1, 0, 0);
    //                       size=24 bits, LSB=8, Read-Only
  endfunction
endclass
```

### Register Bit Layout

```
Bit:  31                    8  7  6  5  4  3  2  1  0
     ├── reserved (RO, 24b)──┤├── speed (RW, 4b)──┤├mode┤en┤
```

### Step 2: Define More Registers

```systemverilog
class status_reg extends uvm_reg;
  `uvm_object_utils(status_reg)

  rand uvm_reg_field busy;
  rand uvm_reg_field error;
  rand uvm_reg_field done;
  rand uvm_reg_field irq;

  function new(string name = "status_reg");
    super.new(name, 32, UVM_NO_COVERAGE);
  endfunction

  virtual function void build();
    busy = uvm_reg_field::type_id::create("busy");
    busy.configure(this, 1, 0, "RO", 1, 1'h0, 1, 0, 0);

    error = uvm_reg_field::type_id::create("error");
    error.configure(this, 1, 1, "RO", 1, 1'h0, 1, 0, 0);

    done = uvm_reg_field::type_id::create("done");
    done.configure(this, 1, 2, "RO", 1, 1'h0, 1, 0, 0);

    irq = uvm_reg_field::type_id::create("irq");
    irq.configure(this, 1, 3, "W1C", 1, 1'h0, 1, 1, 0);
    // W1C = Write-1-to-Clear
  endfunction
endclass

class data_reg extends uvm_reg;
  `uvm_object_utils(data_reg)

  rand uvm_reg_field data;

  function new(string name = "data_reg");
    super.new(name, 32, UVM_NO_COVERAGE);
  endfunction

  virtual function void build();
    data = uvm_reg_field::type_id::create("data");
    data.configure(this, 32, 0, "RW", 0, 32'h0, 1, 1, 0);
  endfunction
endclass
```

### Step 3: Create the Register Block

```systemverilog
class my_reg_block extends uvm_reg_block;
  `uvm_object_utils(my_reg_block)

  rand ctrl_reg   CTRL;
  rand status_reg STATUS;
  rand data_reg   DATA;

  uvm_reg_map default_map;

  function new(string name = "my_reg_block");
    super.new(name, UVM_NO_COVERAGE);
  endfunction

  virtual function void build();
    // Create registers
    CTRL   = ctrl_reg::type_id::create("CTRL");
    STATUS = status_reg::type_id::create("STATUS");
    DATA   = data_reg::type_id::create("DATA");

    // Build registers (creates fields)
    CTRL.build();
    CTRL.configure(this);

    STATUS.build();
    STATUS.configure(this);

    DATA.build();
    DATA.configure(this);

    // Create address map
    default_map = create_map("default_map",
      'h0,    // base address
      4,      // bus width in bytes
      UVM_LITTLE_ENDIAN
    );

    // Add registers to address map
    default_map.add_reg(CTRL,   'h00, "RW");
    default_map.add_reg(STATUS, 'h04, "RO");
    default_map.add_reg(DATA,   'h08, "RW");

    lock_model();
  endfunction
endclass
```

## Adapter: Bridging RAL to Bus Protocol

The adapter converts between `uvm_reg_bus_op` (RAL's abstract bus operation) and your protocol-specific transaction.

```systemverilog
class apb_reg_adapter extends uvm_reg_adapter;
  `uvm_object_utils(apb_reg_adapter)

  function new(string name = "apb_reg_adapter");
    super.new(name);
    supports_byte_enable = 0;
    provides_responses   = 0;
  endfunction

  virtual function uvm_sequence_item reg2bus(const ref uvm_reg_bus_op rw);
    apb_transaction tx = apb_transaction::type_id::create("tx");
    tx.write = (rw.kind == UVM_WRITE);
    tx.addr  = rw.addr;
    if (tx.write)
      tx.data = rw.data;
    return tx;
  endfunction

  virtual function void bus2reg(uvm_sequence_item bus_item, ref uvm_reg_bus_op rw);
    apb_transaction tx;
    if (!$cast(tx, bus_item)) begin
      `uvm_fatal("CAST", "Failed to cast bus_item to apb_transaction")
    end
    rw.kind   = tx.write ? UVM_WRITE : UVM_READ;
    rw.addr   = tx.addr;
    rw.data   = tx.data;
    rw.status = UVM_IS_OK;
  endfunction
endclass
```

## Integrating RAL into the Environment

```systemverilog
class my_env extends uvm_env;
  `uvm_component_utils(my_env)

  apb_agent       agent;
  my_reg_block    reg_model;
  apb_reg_adapter adapter;

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    agent = apb_agent::type_id::create("agent", this);

    // Build register model
    reg_model = my_reg_block::type_id::create("reg_model");
    reg_model.build();

    adapter = apb_reg_adapter::type_id::create("adapter");
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    // Connect RAL to the bus agent
    reg_model.default_map.set_sequencer(agent.sqr, adapter);
    reg_model.default_map.set_auto_predict(1);
  endfunction
endclass
```

## Using RAL in Tests

### Basic Read/Write

```systemverilog
task run_phase(uvm_phase phase);
  uvm_status_e status;
  uvm_reg_data_t data;

  phase.raise_objection(this);

  // Write to CTRL register
  env.reg_model.CTRL.write(status, 32'h0000_0051);
  if (status != UVM_IS_OK)
    `uvm_error("TEST", "CTRL write failed")

  // Read STATUS register
  env.reg_model.STATUS.read(status, data);
  `uvm_info("TEST", $sformatf("STATUS = 0x%08h", data), UVM_LOW)

  // Write individual fields
  env.reg_model.CTRL.enable.set(1);
  env.reg_model.CTRL.mode.set(2'b10);
  env.reg_model.CTRL.speed.set(4'hA);
  env.reg_model.CTRL.update(status);  // sends a single bus write

  // Read individual field (mirror)
  env.reg_model.STATUS.mirror(status, UVM_CHECK);

  phase.drop_objection(this);
endtask
```

### Front-Door vs. Back-Door Access

| Access | Method | Bus Activity | Speed |
|--------|--------|-------------|-------|
| **Front-door** | `read()`, `write()` | Yes — goes through driver | Realistic |
| **Back-door** | `peek()`, `poke()` | No — directly reads/writes RTL | Fast, for setup |

```systemverilog
// Front-door (uses the bus)
env.reg_model.CTRL.write(status, 32'hFF);
env.reg_model.STATUS.read(status, data);

// Back-door (directly accesses RTL — no bus transaction)
env.reg_model.CTRL.poke(status, 32'hFF);
env.reg_model.STATUS.peek(status, data);
```

Back-door access requires setting the HDL path:

```systemverilog
// In the register block build():
CTRL.add_hdl_path_slice("dut.ctrl_reg", 0, 32);
STATUS.add_hdl_path_slice("dut.status_reg", 0, 32);
add_hdl_path("top");
```

## Built-In RAL Test Sequences

UVM provides pre-built sequences for common register tests:

```systemverilog
task run_phase(uvm_phase phase);
  uvm_reg_hw_reset_seq  reset_seq;   // verify reset values
  uvm_reg_bit_bash_seq  bash_seq;    // test each bit individually
  uvm_reg_access_seq    access_seq;  // verify read/write access

  phase.raise_objection(this);

  // Test 1: Verify all registers have correct reset values
  reset_seq = uvm_reg_hw_reset_seq::type_id::create("reset_seq");
  reset_seq.model = env.reg_model;
  reset_seq.start(env.agent.sqr);

  // Test 2: Bit-bash — write walking-1, walking-0 patterns
  bash_seq = uvm_reg_bit_bash_seq::type_id::create("bash_seq");
  bash_seq.model = env.reg_model;
  bash_seq.start(env.agent.sqr);

  // Test 3: Verify register access policies (RW, RO, W1C, etc.)
  access_seq = uvm_reg_access_seq::type_id::create("access_seq");
  access_seq.model = env.reg_model;
  access_seq.start(env.agent.sqr);

  phase.drop_objection(this);
endtask
```

## Register Access Types

| Type | Meaning |
|------|---------|
| `RW` | Read-Write |
| `RO` | Read-Only |
| `WO` | Write-Only |
| `W1C` | Write-1-to-Clear |
| `W1S` | Write-1-to-Set |
| `W0C` | Write-0-to-Clear |
| `RC` | Read-Clear (reading clears the field) |
| `RS` | Read-Set (reading sets the field) |
| `WRC` | Write, Read-Clear |
| `WSRC` | Write-Set, Read-Clear |

## Prediction Models

| Mode | Description |
|------|-------------|
| `auto_predict` | RAL updates the mirror automatically after each front-door access |
| `explicit predict` | A predictor component updates the mirror from monitored bus transactions |

### Explicit Predictor (Recommended for Production)

```systemverilog
class my_env extends uvm_env;
  uvm_reg_predictor #(apb_transaction) predictor;

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    predictor = uvm_reg_predictor #(apb_transaction)::type_id::create("predictor", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    reg_model.default_map.set_sequencer(agent.sqr, adapter);
    reg_model.default_map.set_auto_predict(0);  // disable auto-predict

    predictor.map     = reg_model.default_map;
    predictor.adapter = adapter;
    agent.mon.ap.connect(predictor.bus_in);  // monitor feeds predictor
  endfunction
endclass
```

## Best Practices

1. **Generate the register model** from specification (IP-XACT/SystemRDL) rather than coding by hand.
2. **Use explicit prediction** for production testbenches.
3. **Run built-in sequences** (`hw_reset`, `bit_bash`, `access`) as sanity tests.
4. **Use front-door access** for realistic testing; **back-door** only for fast initialization.
5. **Lock the model** with `lock_model()` after building to catch accidental modifications.

## Next Steps

Continue to [Chapter 3: Functional Coverage](03_functional_coverage.md) to learn about coverage-driven verification.
