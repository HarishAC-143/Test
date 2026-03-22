# UVM Classes and Internal Functions: A Comprehensive Guide

A detailed reference covering every major UVM (Universal Verification Methodology) class, its internal functions, lifecycle phases, and practical usage in SystemVerilog testbenches.

---

## Table of Contents

1. [UVM Overview and Architecture](#1-uvm-overview-and-architecture)
2. [UVM Class Hierarchy](#2-uvm-class-hierarchy)
3. [uvm_void](#3-uvm_void)
4. [uvm_object](#4-uvm_object)
5. [uvm_transaction](#5-uvm_transaction)
6. [uvm_sequence_item](#6-uvm_sequence_item)
7. [uvm_sequence](#7-uvm_sequence)
8. [uvm_component](#8-uvm_component)
9. [uvm_driver](#9-uvm_driver)
10. [uvm_monitor](#10-uvm_monitor)
11. [uvm_sequencer](#11-uvm_sequencer)
12. [uvm_agent](#12-uvm_agent)
13. [uvm_scoreboard](#13-uvm_scoreboard)
14. [uvm_env](#14-uvm_env)
15. [uvm_test](#15-uvm_test)
16. [UVM Phases In Detail](#16-uvm-phases-in-detail)
17. [UVM Factory](#17-uvm-factory)
18. [UVM Configuration Database](#18-uvm-configuration-database)
19. [UVM TLM Ports and Communication](#19-uvm-tlm-ports-and-communication)
20. [UVM Reporting and Messaging](#20-uvm-reporting-and-messaging)
21. [UVM Register Layer (UVM RAL)](#21-uvm-register-layer-uvm-ral)
22. [UVM Field Automation Macros](#22-uvm-field-automation-macros)
23. [UVM Callbacks](#23-uvm-callbacks)
24. [Complete UVM Testbench Example](#24-complete-uvm-testbench-example)

---

## 1. UVM Overview and Architecture

UVM (Universal Verification Methodology) is a standardized methodology for verifying integrated circuit designs using SystemVerilog. It provides a class library, a set of coding guidelines, and automation utilities that enable building reusable, scalable verification environments.

### Why UVM?

- **Reusability**: Components can be reused across projects with minimal modification.
- **Scalability**: Hierarchical architecture supports simple blocks to full SoC verification.
- **Standardization**: IEEE 1800.2 standard ensures vendor-independent portability.
- **Automation**: Factory pattern, configuration database, and field macros reduce boilerplate.
- **Phasing**: Structured simulation phases ensure deterministic build-up and teardown.

### UVM Testbench Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                          uvm_test                                │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │                        uvm_env                             │  │
│  │  ┌──────────────────────┐  ┌────────────────────────────┐ │  │
│  │  │     uvm_agent        │  │      uvm_scoreboard        │ │  │
│  │  │  ┌────────────────┐  │  │                            │ │  │
│  │  │  │ uvm_sequencer  │  │  │  Reference Model +         │ │  │
│  │  │  └───────┬────────┘  │  │  Comparison Logic          │ │  │
│  │  │          │           │  │                            │ │  │
│  │  │  ┌───────▼────────┐  │  └────────────────────────────┘ │  │
│  │  │  │  uvm_driver    │  │                                 │  │
│  │  │  └───────┬────────┘  │  ┌────────────────────────────┐ │  │
│  │  │          │           │  │    Coverage Collector       │ │  │
│  │  │  ┌───────▼────────┐  │  └────────────────────────────┘ │  │
│  │  │  │  uvm_monitor   │  │                                 │  │
│  │  │  └────────────────┘  │                                 │  │
│  │  └──────────────────────┘                                 │  │
│  └────────────────────────────────────────────────────────────┘  │
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │  uvm_sequence (generates uvm_sequence_item transactions)  │  │
│  └────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────┘
                            │
                     ┌──────▼──────┐
                     │     DUT     │
                     │  (Design    │
                     │  Under Test)│
                     └─────────────┘
```

### Key Principles

| Principle | Description |
|---|---|
| **Separation of Concerns** | Stimulus generation, driving, monitoring, and checking are isolated in separate components |
| **Transaction-Level Modeling** | Communication uses abstract transactions, not signal-level toggles |
| **Factory Pattern** | Objects and components are created through a factory enabling type overrides |
| **Configuration Database** | Hierarchical key-value store for passing configuration without hard-coding |
| **Phasing** | Simulation proceeds through well-defined phases (build, connect, run, etc.) |

---

## 2. UVM Class Hierarchy

The UVM class library follows a strict inheritance hierarchy. Understanding this tree is fundamental to using UVM effectively.

```
uvm_void
├── uvm_object
│   ├── uvm_transaction
│   │   └── uvm_sequence_item
│   │       └── uvm_sequence
│   ├── uvm_report_object
│   │   └── uvm_component
│   │       ├── uvm_test
│   │       ├── uvm_env
│   │       ├── uvm_agent
│   │       ├── uvm_driver
│   │       ├── uvm_monitor
│   │       ├── uvm_sequencer
│   │       ├── uvm_scoreboard
│   │       └── uvm_subscriber
│   ├── uvm_reg_field
│   ├── uvm_reg
│   ├── uvm_reg_block
│   ├── uvm_reg_map
│   ├── uvm_event
│   ├── uvm_barrier
│   ├── uvm_callback
│   └── uvm_packer / uvm_comparer / uvm_printer / uvm_recorder
└── uvm_port_base
    ├── uvm_*_port
    ├── uvm_*_export
    └── uvm_*_imp
```

### Two Fundamental Branches

| Branch | Base Class | Has Hierarchy? | Has Phases? | Primary Use |
|---|---|---|---|---|
| **Data** | `uvm_object` | No | No | Transactions, configuration objects, policies |
| **Structural** | `uvm_component` | Yes (parent/child) | Yes (build, connect, run...) | Testbench architecture components |

---

## 3. uvm_void

`uvm_void` is the abstract root of the entire UVM class hierarchy. It contains no data members and no methods. Its sole purpose is to provide a common base type so that both `uvm_object` and `uvm_port_base` share a single ancestor, enabling generic containers and polymorphism at the highest level.

```systemverilog
virtual class uvm_void;
  // No data members
  // No methods
endclass
```

### Why It Exists

- Allows generic handles: `uvm_void handle;` can point to any UVM object or port.
- Enables heterogeneous collections (arrays of `uvm_void` handles).
- Serves as the polymorphic root for the two major branches: `uvm_object` (data) and `uvm_port_base` (TLM communication).

You will almost never interact with `uvm_void` directly; it exists purely as an architectural foundation.

---

## 4. uvm_object

`uvm_object` is the most important base class in UVM. It provides the core utility infrastructure that all UVM data objects and components inherit: copying, comparing, printing, packing, unpacking, recording, and factory registration.

### Class Declaration

```systemverilog
class uvm_object extends uvm_void;
```

### Internal Functions — Complete Reference

#### 4.1 Construction

| Method | Signature | Description |
|---|---|---|
| `new` | `function new(string name = "")` | Constructor. The `name` argument provides an instance name used in printing and debugging. |

```systemverilog
class my_obj extends uvm_object;
  `uvm_object_utils(my_obj)

  function new(string name = "my_obj");
    super.new(name);
  endfunction
endclass
```

#### 4.2 Identification Methods

| Method | Signature | Description |
|---|---|---|
| `get_name` | `function string get_name()` | Returns the instance name passed to the constructor. |
| `get_full_name` | `function string get_full_name()` | Returns the full hierarchical name. For `uvm_object`, same as `get_name`. For `uvm_component`, includes the parent hierarchy. |
| `get_type_name` | `virtual function string get_type_name()` | Returns the type name string (e.g., `"my_obj"`). Must be implemented by the `uvm_object_utils` macro or manually. |
| `get_inst_id` | `function int get_inst_id()` | Returns a unique integer ID assigned at construction. Every `uvm_object` instance gets a distinct ID. |
| `get_object_type` | `function uvm_object_wrapper get_object_type()` | Returns the factory proxy object for this type. Used by the factory for type resolution. |
| `set_name` | `function void set_name(string name)` | Changes the instance name post-construction. |

```systemverilog
my_obj obj = my_obj::type_id::create("obj1");
$display("Name: %s", obj.get_name());           // "obj1"
$display("Type: %s", obj.get_type_name());       // "my_obj"
$display("ID:   %0d", obj.get_inst_id());        // unique integer
```

#### 4.3 Core Data Methods (The "do" Hooks)

These are the most critical methods in `uvm_object`. Each public method (e.g., `copy`) calls a corresponding virtual `do_*` hook that you override to define class-specific behavior.

| Public Method | Virtual Hook | Purpose |
|---|---|---|
| `copy(uvm_object rhs)` | `do_copy(uvm_object rhs)` | Deep copy all fields from `rhs` into `this` |
| `clone()` | — (calls `create` + `copy`) | Create a new object and copy fields into it |
| `compare(uvm_object rhs, uvm_comparer comparer = null)` | `do_compare(uvm_object rhs, uvm_comparer comparer)` | Field-by-field comparison; returns 1 if equal |
| `print(uvm_printer printer = null)` | `do_print(uvm_printer printer)` | Print all fields in a formatted table |
| `sprint(uvm_printer printer = null)` | — (calls `do_print`) | Same as `print` but returns a string |
| `record(uvm_recorder recorder = null)` | `do_record(uvm_recorder recorder)` | Record fields for waveform/database viewing |
| `pack(ref bit bitstream[], input uvm_packer packer = null)` | `do_pack(uvm_packer packer)` | Serialize fields into a bit vector |
| `pack_bytes(ref byte unsigned bytstream[], ...)` | `do_pack(uvm_packer packer)` | Serialize fields into a byte vector |
| `pack_ints(ref int unsigned intstream[], ...)` | `do_pack(uvm_packer packer)` | Serialize fields into an int vector |
| `unpack(ref bit bitstream[], ...)` | `do_unpack(uvm_packer packer)` | Deserialize from a bit vector |
| `unpack_bytes(ref byte unsigned bytestream[], ...)` | `do_unpack(uvm_packer packer)` | Deserialize from a byte vector |
| `unpack_ints(ref int unsigned intstream[], ...)` | `do_unpack(uvm_packer packer)` | Deserialize from an int vector |
| `convert2string()` | — | Returns a human-readable string representation |

##### Deep Dive: copy and do_copy

```systemverilog
class apb_transaction extends uvm_sequence_item;
  rand bit [31:0] addr;
  rand bit [31:0] data;
  rand bit        write;

  `uvm_object_utils(apb_transaction)

  function new(string name = "apb_transaction");
    super.new(name);
  endfunction

  // Manual do_copy implementation
  virtual function void do_copy(uvm_object rhs);
    apb_transaction rhs_cast;
    super.do_copy(rhs);  // Always call super first
    if (!$cast(rhs_cast, rhs))
      `uvm_fatal("COPY", "Cast failed in do_copy")
    this.addr  = rhs_cast.addr;
    this.data  = rhs_cast.data;
    this.write = rhs_cast.write;
  endfunction
endclass

// Usage:
apb_transaction t1, t2;
t1 = apb_transaction::type_id::create("t1");
t1.addr = 32'hDEAD_BEEF;
t2 = apb_transaction::type_id::create("t2");
t2.copy(t1);  // t2 now has addr = 32'hDEAD_BEEF
```

##### Deep Dive: compare and do_compare

```systemverilog
virtual function bit do_compare(uvm_object rhs, uvm_comparer comparer);
  apb_transaction rhs_cast;
  bit status = super.do_compare(rhs, comparer);
  if (!$cast(rhs_cast, rhs))
    return 0;
  status &= comparer.compare_field_int("addr",  this.addr,  rhs_cast.addr,  32);
  status &= comparer.compare_field_int("data",  this.data,  rhs_cast.data,  32);
  status &= comparer.compare_field_int("write", this.write, rhs_cast.write, 1);
  return status;
endfunction

// Usage:
if (t1.compare(t2))
  `uvm_info("CMP", "Transactions match", UVM_LOW)
else
  `uvm_error("CMP", "Transaction mismatch")
```

##### Deep Dive: print and do_print

```systemverilog
virtual function void do_print(uvm_printer printer);
  super.do_print(printer);
  printer.print_field_int("addr",  addr,  32, UVM_HEX);
  printer.print_field_int("data",  data,  32, UVM_HEX);
  printer.print_field_int("write", write, 1,  UVM_BIN);
endfunction

// Usage:
t1.print();  // Prints formatted table to console
```

Output:

```
---------------------------------------
Name         Type              Size  Value
---------------------------------------
t1           apb_transaction   -     @123
  addr       integral          32    'hdead_beef
  data       integral          32    'h0000_0042
  write      integral          1     'b1
---------------------------------------
```

##### Deep Dive: pack / unpack and do_pack / do_unpack

```systemverilog
virtual function void do_pack(uvm_packer packer);
  super.do_pack(packer);
  packer.pack_field_int(addr,  32);
  packer.pack_field_int(data,  32);
  packer.pack_field_int(write, 1);
endfunction

virtual function void do_unpack(uvm_packer packer);
  super.do_unpack(packer);
  addr  = packer.unpack_field_int(32);
  data  = packer.unpack_field_int(32);
  write = packer.unpack_field_int(1);
endfunction

// Usage:
bit bitstream[];
t1.pack(bitstream);        // Serialize: 65 bits total
t2.unpack(bitstream);      // Deserialize: t2 now mirrors t1
```

##### Deep Dive: clone

```systemverilog
// clone() = create() + copy()
uvm_object cloned = t1.clone();
apb_transaction t3;
$cast(t3, cloned);
// t3 is a new object with all fields copied from t1
```

##### Deep Dive: convert2string

```systemverilog
virtual function string convert2string();
  return $sformatf("addr=0x%08h data=0x%08h write=%0b", addr, data, write);
endfunction

// Usage:
`uvm_info("TXN", t1.convert2string(), UVM_MEDIUM)
```

#### 4.4 Factory Registration

Every `uvm_object` subclass should be registered with the UVM factory using one of these macros:

| Macro | Use Case |
|---|---|
| `` `uvm_object_utils(T) `` | Non-parameterized classes |
| `` `uvm_object_param_utils(T) `` | Parameterized classes |
| `` `uvm_object_utils_begin(T) / `uvm_object_utils_end `` | Non-parameterized with field automation |
| `` `uvm_object_param_utils_begin(T) / `uvm_object_utils_end `` | Parameterized with field automation |

```systemverilog
class my_config extends uvm_object;
  `uvm_object_utils(my_config)

  int num_agents = 1;
  bit enable_coverage = 1;

  function new(string name = "my_config");
    super.new(name);
  endfunction
endclass
```

---

## 5. uvm_transaction

`uvm_transaction` extends `uvm_object` and adds timing and recording capabilities needed for tracking transactions through a simulation timeline.

### Class Declaration

```systemverilog
class uvm_transaction extends uvm_object;
```

### Additional Methods Over uvm_object

| Method | Signature | Description |
|---|---|---|
| `accept_tr` | `function void accept_tr(time accept_time = 0)` | Mark the time the transaction was accepted by a component. Triggers `begin_event`. |
| `begin_tr` | `function int begin_tr(time begin_time = 0, int parent_handle = 0)` | Mark the start of processing. Returns a transaction handle for recording. |
| `end_tr` | `function void end_tr(time end_time = 0, bit free_handle = 1)` | Mark the end of processing. |
| `do_accept_tr` | `virtual protected function void do_accept_tr()` | User hook called by `accept_tr`. |
| `do_begin_tr` | `virtual protected function void do_begin_tr()` | User hook called by `begin_tr`. |
| `do_end_tr` | `virtual protected function void do_end_tr()` | User hook called by `end_tr`. |
| `get_accept_time` | `function time get_accept_time()` | Returns the time set by `accept_tr`. |
| `get_begin_time` | `function time get_begin_time()` | Returns the time set by `begin_tr`. |
| `get_end_time` | `function time get_end_time()` | Returns the time set by `end_tr`. |
| `get_tr_handle` | `function int get_tr_handle()` | Returns the database handle for the transaction. |
| `set_initiator` | `function void set_initiator(uvm_component initiator)` | Records which component initiated this transaction. |
| `get_initiator` | `function uvm_component get_initiator()` | Returns the initiating component. |
| `get_event_pool` | `function uvm_event_pool get_event_pool()` | Returns the event pool for `begin_event` and `end_event`. |
| `set_transaction_id` | `function void set_transaction_id(int id)` | Assign a transaction ID. |
| `get_transaction_id` | `function int get_transaction_id()` | Returns the transaction ID. |

### Transaction Recording Timeline

```
              accept_tr          begin_tr           end_tr
                 │                  │                  │
    ─────────────┼──────────────────┼──────────────────┼──────────
                 │                  │                  │
            Transaction      Driver starts       Driver completes
            received by      processing           bus transfer
            the driver       (pin wiggling)
```

> **Note**: In practice, you rarely use `uvm_transaction` directly. Instead, extend `uvm_sequence_item` which inherits from `uvm_transaction`.

---

## 6. uvm_sequence_item

`uvm_sequence_item` is the primary base class for all transaction objects passed between sequences and drivers. It extends `uvm_transaction` and adds sequence/sequencer awareness.

### Class Declaration

```systemverilog
class uvm_sequence_item extends uvm_transaction;
```

### Key Internal Methods

| Method | Signature | Description |
|---|---|---|
| `new` | `function new(string name = "uvm_sequence_item")` | Constructor |
| `get_sequence_id` | `function int get_sequence_id()` | Returns the ID of the parent sequence |
| `set_sequence_id` | `function void set_sequence_id(int id)` | Sets the parent sequence ID |
| `set_item_context` | `function void set_item_context(uvm_sequence_base parent_seq, uvm_sequencer_base sequencer = null)` | Establishes the item's relationship to its parent sequence and sequencer |
| `get_sequencer` | `function uvm_sequencer_base get_sequencer()` | Returns the sequencer this item is running on |
| `set_sequencer` | `function void set_sequencer(uvm_sequencer_base sequencer)` | Sets the sequencer reference |
| `get_parent_sequence` | `function uvm_sequence_base get_parent_sequence()` | Returns the parent sequence that generated this item |
| `set_parent_sequence` | `function void set_parent_sequence(uvm_sequence_base parent)` | Sets the parent sequence reference |
| `get_depth` | `function int get_depth()` | Returns the nesting depth in the sequence hierarchy |
| `get_root_sequence_name` | `function string get_root_sequence_name()` | Returns the name of the outermost ancestor sequence |
| `set_id_info` | `function void set_id_info(uvm_sequence_item item)` | Copy sequence/transaction ID info from another item (used for response routing) |

### Practical Example: A Complete Sequence Item

```systemverilog
class axi_transaction extends uvm_sequence_item;

  // Transaction fields
  rand bit [31:0] addr;
  rand bit [31:0] data[];
  rand bit [3:0]  burst_len;
  rand bit [2:0]  burst_size;
  rand bit [1:0]  burst_type;
  rand bit        read_write;   // 0=read, 1=write

  // Response fields (filled by driver)
  bit [1:0] response;

  // Constraints
  constraint valid_burst_len_c {
    burst_len inside {0, 1, 3, 7, 15};
  }

  constraint data_size_c {
    data.size() == burst_len + 1;
  }

  constraint addr_alignment_c {
    addr[1:0] == 2'b00;  // Word-aligned
  }

  `uvm_object_utils_begin(axi_transaction)
    `uvm_field_int(addr,        UVM_ALL_ON | UVM_HEX)
    `uvm_field_array_int(data,  UVM_ALL_ON | UVM_HEX)
    `uvm_field_int(burst_len,   UVM_ALL_ON | UVM_DEC)
    `uvm_field_int(burst_size,  UVM_ALL_ON | UVM_DEC)
    `uvm_field_int(burst_type,  UVM_ALL_ON | UVM_DEC)
    `uvm_field_int(read_write,  UVM_ALL_ON | UVM_BIN)
    `uvm_field_int(response,    UVM_ALL_ON | UVM_DEC)
  `uvm_object_utils_end

  function new(string name = "axi_transaction");
    super.new(name);
  endfunction

  virtual function string convert2string();
    string s = $sformatf("%s: addr=0x%08h %s burst_len=%0d",
                         get_name(), addr,
                         read_write ? "WRITE" : "READ",
                         burst_len);
    if (read_write) begin
      foreach (data[i])
        s = {s, $sformatf("\n  data[%0d]=0x%08h", i, data[i])};
    end
    return s;
  endfunction
endclass
```

---

## 7. uvm_sequence

`uvm_sequence` is the base class for all sequences. A sequence is a procedural object that generates a stream of `uvm_sequence_item` transactions and sends them to a sequencer, which in turn passes them to a driver.

### Class Declaration

```systemverilog
class uvm_sequence #(type REQ = uvm_sequence_item,
                     type RSP = REQ) extends uvm_sequence_item;
```

### Key Internal Methods

#### 7.1 Core Execution Methods

| Method | Signature | Description |
|---|---|---|
| `body` | `virtual task body()` | **The main method you override.** Contains the stimulus generation logic. Called by `start()`. |
| `start` | `task start(uvm_sequencer_base sequencer, uvm_sequence_base parent_sequence = null, int this_priority = -1, bit call_pre_post = 1)` | Initiates the sequence on the given sequencer. Calls `pre_body`, `body`, `post_body`. |
| `pre_body` | `virtual task pre_body()` | Called before `body()`. Override for setup. |
| `post_body` | `virtual task post_body()` | Called after `body()`. Override for cleanup. |
| `pre_start` | `virtual task pre_start()` | Called at the very beginning of `start()`, before `pre_body`. |
| `post_start` | `virtual task post_start()` | Called at the very end of `start()`, after `post_body`. |

#### 7.2 Sequence Item Communication Methods

| Method | Signature | Description |
|---|---|---|
| `create_item` | `function uvm_sequence_item create_item(uvm_object_wrapper type_var, uvm_sequencer_base l_sequencer, string name)` | Create a sequence item through the factory |
| `start_item` | `task start_item(uvm_sequence_item item, int set_priority = -1, uvm_sequencer_base sequencer = null)` | Request arbitration access from the sequencer for the given item |
| `finish_item` | `task finish_item(uvm_sequence_item item, int set_priority = -1)` | Send the item to the driver and wait for `item_done` |
| `wait_for_grant` | `task wait_for_grant(int item_priority = -1, bit lock_request = 0)` | Wait until the sequencer grants permission (lower-level than `start_item`) |
| `send_request` | `function void send_request(uvm_sequence_item request, bit rerandomize = 0)` | Send the item to the driver (lower-level than `finish_item`) |
| `get_response` | `task get_response(output RSP response, input int transaction_id = -1)` | Wait for and retrieve the driver's response |
| `get_current_item` | `function uvm_sequence_item get_current_item()` | Returns the current item being processed |
| `put_response` | `virtual function void put_response(uvm_sequence_item response)` | Called when driver sends a response back |

#### 7.3 Sequence Control Methods

| Method | Signature | Description |
|---|---|---|
| `set_sequencer` | `virtual function void set_sequencer(uvm_sequencer_base sequencer)` | Bind the sequence to a sequencer |
| `get_sequencer` | `function uvm_sequencer_base get_sequencer()` | Returns the bound sequencer |
| `set_priority` | `function void set_priority(int value)` | Set the sequence's arbitration priority |
| `get_priority` | `function int get_priority()` | Get the current priority |
| `is_blocked` | `function bit is_blocked()` | Returns 1 if the sequence is waiting for grant |
| `is_relevant` | `virtual function bit is_relevant()` | Override to control when a sequence is eligible for arbitration |
| `wait_for_relevant` | `virtual task wait_for_relevant()` | Called when `is_relevant()` returns 0 |
| `lock` | `task lock(uvm_sequencer_base sequencer = null)` | Lock the sequencer (exclusive access) |
| `unlock` | `function void unlock(uvm_sequencer_base sequencer = null)` | Release the lock |
| `grab` | `task grab(uvm_sequencer_base sequencer = null)` | Like `lock` but takes precedence over pending requests |
| `ungrab` | `function void ungrab(uvm_sequencer_base sequencer = null)` | Release the grab |
| `kill` | `function void kill()` | Forcibly terminate the sequence |
| `do_kill` | `virtual function void do_kill()` | User hook called by `kill()` for cleanup |
| `set_automatic_phase_objection` | `function void set_automatic_phase_objection(bit value)` | Automatically raise/drop objection during body() |

#### 7.4 Execution Flow

```
start() called
  │
  ├── pre_start()
  │
  ├── pre_body()           [if call_pre_post=1]
  │
  ├── body()               ◄── YOUR CODE HERE
  │   │
  │   ├── start_item(item)   ──► Arbitration request to sequencer
  │   │       │                    Sequencer grants when ready
  │   │       ▼
  │   ├── item.randomize()   ──► Randomize after grant (late randomization)
  │   │       │
  │   │       ▼
  │   └── finish_item(item)  ──► Send to driver, wait for item_done
  │
  ├── post_body()          [if call_pre_post=1]
  │
  └── post_start()
```

### Practical Examples

#### Simple Sequence

```systemverilog
class apb_write_seq extends uvm_sequence #(apb_transaction);
  `uvm_object_utils(apb_write_seq)

  rand bit [31:0] target_addr;
  rand bit [31:0] target_data;

  function new(string name = "apb_write_seq");
    super.new(name);
  endfunction

  virtual task body();
    apb_transaction txn;
    txn = apb_transaction::type_id::create("txn");

    start_item(txn);
    if (!txn.randomize() with {
      addr  == target_addr;
      data  == target_data;
      write == 1;
    }) `uvm_fatal("RAND", "Randomization failed")
    finish_item(txn);

    `uvm_info(get_type_name(),
              $sformatf("Wrote 0x%08h to 0x%08h", txn.data, txn.addr),
              UVM_MEDIUM)
  endtask
endclass
```

#### Sequence with Response

```systemverilog
class apb_read_seq extends uvm_sequence #(apb_transaction);
  `uvm_object_utils(apb_read_seq)

  rand bit [31:0] target_addr;
  bit [31:0] read_data;

  function new(string name = "apb_read_seq");
    super.new(name);
  endfunction

  virtual task body();
    apb_transaction req, rsp;
    req = apb_transaction::type_id::create("req");

    start_item(req);
    if (!req.randomize() with {
      addr  == target_addr;
      write == 0;
    }) `uvm_fatal("RAND", "Randomization failed")
    finish_item(req);

    get_response(rsp);
    read_data = rsp.data;

    `uvm_info(get_type_name(),
              $sformatf("Read 0x%08h from 0x%08h", read_data, target_addr),
              UVM_MEDIUM)
  endtask
endclass
```

#### Sequence Composing Other Sequences (Virtual Sequence)

```systemverilog
class apb_rw_sequence extends uvm_sequence #(apb_transaction);
  `uvm_object_utils(apb_rw_sequence)

  function new(string name = "apb_rw_sequence");
    super.new(name);
  endfunction

  virtual task body();
    apb_write_seq wr_seq;
    apb_read_seq  rd_seq;

    // Write then read-back
    repeat (10) begin
      wr_seq = apb_write_seq::type_id::create("wr_seq");
      rd_seq = apb_read_seq::type_id::create("rd_seq");

      if (!wr_seq.randomize()) `uvm_fatal("RAND", "Failed")
      wr_seq.start(m_sequencer);

      rd_seq.target_addr = wr_seq.target_addr;
      rd_seq.start(m_sequencer);

      if (rd_seq.read_data !== wr_seq.target_data)
        `uvm_error("CHECK", $sformatf("Mismatch at 0x%08h: wrote 0x%08h, read 0x%08h",
                   wr_seq.target_addr, wr_seq.target_data, rd_seq.read_data))
    end
  endtask
endclass
```

#### Using `uvm_do` Macros (Shorthand)

```systemverilog
virtual task body();
  apb_transaction txn;

  // `uvm_do combines create + start_item + randomize + finish_item
  `uvm_do(txn)

  // `uvm_do_with adds inline constraints
  `uvm_do_with(txn, {
    addr == 32'h1000;
    write == 1;
  })

  // `uvm_do_on sends to a specific sequencer
  `uvm_do_on(txn, target_sequencer)

  // `uvm_do_on_with combines both
  `uvm_do_on_with(txn, target_sequencer, {
    addr inside {[32'h0000 : 32'h0FFF]};
  })

  // `uvm_do_pri sets priority
  `uvm_do_pri(txn, 200)
endtask
```

> **Best Practice**: Prefer the explicit `start_item`/`finish_item` flow over `uvm_do` macros for better readability and debuggability.

---

## 8. uvm_component

`uvm_component` is the base class for all structural (persistent) elements of a UVM testbench. Unlike `uvm_object`, components exist for the entire simulation, form a hierarchical tree (parent/child relationships), and participate in simulation phases.

### Class Declaration

```systemverilog
class uvm_component extends uvm_report_object;
```

### Key Internal Methods

#### 8.1 Construction and Hierarchy

| Method | Signature | Description |
|---|---|---|
| `new` | `function new(string name, uvm_component parent)` | Constructor. `parent` establishes the hierarchy. `null` parent is only valid for `uvm_root`. |
| `get_parent` | `function uvm_component get_parent()` | Returns the parent component |
| `get_full_name` | `function string get_full_name()` | Returns dot-separated hierarchical path (e.g., `"uvm_test_top.env.agent.driver"`) |
| `get_name` | `function string get_name()` | Returns the local instance name |
| `get_children` | `function void get_children(ref uvm_component children[$])` | Returns all child components |
| `get_child` | `function uvm_component get_child(string name)` | Returns a specific child by name |
| `get_num_children` | `function int get_num_children()` | Returns the number of children |
| `get_first_child` | `function int get_first_child(ref string name)` | Iterator: get first child |
| `get_next_child` | `function int get_next_child(ref string name)` | Iterator: get next child |
| `has_child` | `function int has_child(string name)` | Returns 1 if a child with the given name exists |
| `lookup` | `function uvm_component lookup(string name)` | Find a component by hierarchical path (absolute or relative) |
| `get_depth` | `function int unsigned get_depth()` | Returns the depth in the component hierarchy (root = 0) |

#### 8.2 Phase Methods (Virtual — Override These)

| Method | Signature | Description |
|---|---|---|
| `build_phase` | `virtual function void build_phase(uvm_phase phase)` | Construct sub-components, get configuration. Top-down execution. |
| `connect_phase` | `virtual function void connect_phase(uvm_phase phase)` | Connect TLM ports/exports. Bottom-up execution. |
| `end_of_elaboration_phase` | `virtual function void end_of_elaboration_phase(uvm_phase phase)` | Final topology adjustments, debug display. Bottom-up. |
| `start_of_simulation_phase` | `virtual function void start_of_simulation_phase(uvm_phase phase)` | Pre-simulation setup (print topology, banners). Bottom-up. |
| `run_phase` | `virtual task run_phase(uvm_phase phase)` | Main simulation phase. All components run in parallel. Time-consuming. |
| `pre_reset_phase` | `virtual task pre_reset_phase(uvm_phase phase)` | Runtime sub-phase: before reset |
| `reset_phase` | `virtual task reset_phase(uvm_phase phase)` | Runtime sub-phase: apply reset |
| `post_reset_phase` | `virtual task post_reset_phase(uvm_phase phase)` | Runtime sub-phase: after reset |
| `pre_configure_phase` | `virtual task pre_configure_phase(uvm_phase phase)` | Runtime sub-phase: before configure |
| `configure_phase` | `virtual task configure_phase(uvm_phase phase)` | Runtime sub-phase: configure DUT |
| `post_configure_phase` | `virtual task post_configure_phase(uvm_phase phase)` | Runtime sub-phase: after configure |
| `pre_main_phase` | `virtual task pre_main_phase(uvm_phase phase)` | Runtime sub-phase: before main |
| `main_phase` | `virtual task main_phase(uvm_phase phase)` | Runtime sub-phase: main stimulus |
| `post_main_phase` | `virtual task post_main_phase(uvm_phase phase)` | Runtime sub-phase: after main |
| `pre_shutdown_phase` | `virtual task pre_shutdown_phase(uvm_phase phase)` | Runtime sub-phase: before shutdown |
| `shutdown_phase` | `virtual task shutdown_phase(uvm_phase phase)` | Runtime sub-phase: shutdown |
| `post_shutdown_phase` | `virtual task post_shutdown_phase(uvm_phase phase)` | Runtime sub-phase: after shutdown |
| `extract_phase` | `virtual function void extract_phase(uvm_phase phase)` | Extract results from scoreboards, coverage collectors. Bottom-up. |
| `check_phase` | `virtual function void check_phase(uvm_phase phase)` | Check for errors, verify pass/fail. Bottom-up. |
| `report_phase` | `virtual function void report_phase(uvm_phase phase)` | Generate reports, summaries. Bottom-up. |
| `final_phase` | `virtual function void final_phase(uvm_phase phase)` | Last opportunity for cleanup. |
| `phase_started` | `virtual function void phase_started(uvm_phase phase)` | Called when any phase begins |
| `phase_ready_to_end` | `virtual function void phase_ready_to_end(uvm_phase phase)` | Called when a phase is about to end (drain time hook) |
| `phase_ended` | `virtual function void phase_ended(uvm_phase phase)` | Called when any phase ends |

#### 8.3 Configuration Methods

| Method | Signature | Description |
|---|---|---|
| `set_config_int` | `function void set_config_int(string inst_name, string field_name, uvm_bitstream_t value)` | **Deprecated.** Use `uvm_config_db` instead. |
| `set_config_string` | `function void set_config_string(string inst_name, string field_name, string value)` | **Deprecated.** Use `uvm_config_db` instead. |
| `set_config_object` | `function void set_config_object(string inst_name, string field_name, uvm_object value, bit clone = 1)` | **Deprecated.** Use `uvm_config_db` instead. |
| `apply_config_settings` | `virtual function void apply_config_settings(bit verbose = 0)` | Apply all configuration settings matching this component |

#### 8.4 Factory Methods

| Method | Signature | Description |
|---|---|---|
| `create_component` | `function uvm_component create_component(string requested_type, string name)` | Create a component through the factory |
| `create_object` | `function uvm_object create_object(string requested_type, string name = "")` | Create an object through the factory |
| `set_type_override_by_type` | `static function void set_type_override_by_type(uvm_object_wrapper original, uvm_object_wrapper override, bit replace = 1)` | Override a type factory-wide |
| `set_inst_override_by_type` | `function void set_inst_override_by_type(string relative_inst_path, uvm_object_wrapper original, uvm_object_wrapper override)` | Override a type for a specific instance path |

#### 8.5 Objection Methods

| Method | Signature | Description |
|---|---|---|
| `raise_objection` | (via phase.raise_objection) | Prevent a phase from ending |
| `drop_objection` | (via phase.drop_objection) | Allow a phase to end |

#### 8.6 Printing and Topology

| Method | Signature | Description |
|---|---|---|
| `print_override_info` | `function void print_override_info(string requested_type, string name = "")` | Print factory override info |
| `print` | (inherited from `uvm_object`) | Print this component |
| `set_report_verbosity_level` | `function void set_report_verbosity_level(int verbosity)` | Set message verbosity threshold |
| `set_report_verbosity_level_hier` | `function void set_report_verbosity_level_hier(int verbosity)` | Set verbosity for this component and all descendants |

#### 8.7 Recording / Reporting

| Method | Signature | Description |
|---|---|---|
| `accept_tr` | `function void accept_tr(uvm_transaction tr, time accept_time = 0)` | Record transaction acceptance |
| `begin_tr` | `function int begin_tr(uvm_transaction tr, string stream_name = "main", string label = "", string desc = "", time begin_time = 0, int parent_handle = 0)` | Start recording a transaction |
| `end_tr` | `function void end_tr(uvm_transaction tr, time end_time = 0, bit free_handle = 1)` | End recording a transaction |

### Factory Registration for Components

```systemverilog
class my_agent extends uvm_agent;
  `uvm_component_utils(my_agent)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
endclass
```

> **Critical Difference**: `uvm_object` subclasses use `uvm_object_utils` and have `new(string name)`. `uvm_component` subclasses use `uvm_component_utils` and have `new(string name, uvm_component parent)`.

---

## 9. uvm_driver

`uvm_driver` is a parameterized component that receives transactions from a sequencer and converts them into pin-level activity on the DUT interface. It is the bridge between abstract transaction-level sequences and the signal-level DUT pins.

### Class Declaration

```systemverilog
class uvm_driver #(type REQ = uvm_sequence_item,
                   type RSP = REQ) extends uvm_component;
```

### Built-in Members

| Member | Type | Description |
|---|---|---|
| `seq_item_port` | `uvm_seq_item_pull_port #(REQ, RSP)` | Port connected to the sequencer to pull transactions |
| `rsp_port` | `uvm_analysis_port #(RSP)` | Port to broadcast responses to subscribers |
| `req` | `REQ` | Handle to the current request transaction |
| `rsp` | `RSP` | Handle to the current response transaction |

### Key Inherited + Driver-Specific Methods

| Method | Signature | Description |
|---|---|---|
| `new` | `function new(string name, uvm_component parent)` | Constructor |
| `build_phase` | Inherited | Build sub-components |
| `connect_phase` | Inherited | Connect `seq_item_port` to sequencer's `seq_item_export` |
| `run_phase` | Override this | Main driving logic — fetch and drive transactions |

### Sequencer-Driver Communication Protocol

The driver communicates with the sequencer using these methods on `seq_item_port`:

| Method | Description |
|---|---|
| `get_next_item(req)` | **Blocking** — wait for the next transaction from the sequencer |
| `try_next_item(req)` | **Non-blocking** — attempt to get a transaction; returns `null` if none available |
| `item_done(rsp)` | Signal the sequencer that the current item is complete; optionally send response |
| `put(rsp)` | Send a response back to the sequence (alternative to passing `rsp` in `item_done`) |
| `get(req)` | Combined `get_next_item` + `item_done` (no response) |
| `peek(req)` | Get the next item without removing it from the sequencer's queue |

### Protocol: get_next_item / item_done vs get

```
Method 1: get_next_item + item_done (RECOMMENDED)
─────────────────────────────────────────────────
  Sequencer                     Driver
     │                            │
     │   get_next_item(req) ◄─────┤  (blocks until item available)
     ├────── req ─────────────────►│
     │                            │  drive_bus(req)
     │                            │  ...pin wiggling...
     │   item_done(rsp)    ◄──────┤  (unblocks finish_item in sequence)
     │                            │

Method 2: get (combines both, no response possible)
───────────────────────────────────────────────────
  Sequencer                     Driver
     │                            │
     │   get(req)          ◄──────┤  (blocks, then auto-calls item_done)
     ├────── req ─────────────────►│
     │                            │
```

### Practical Example: APB Driver

```systemverilog
class apb_driver extends uvm_driver #(apb_transaction);
  `uvm_component_utils(apb_driver)

  virtual apb_if vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual apb_if)::get(this, "", "vif", vif))
      `uvm_fatal("NOVIF", "Virtual interface not found in config DB")
  endfunction

  virtual task run_phase(uvm_phase phase);
    apb_transaction txn;
    forever begin
      seq_item_port.get_next_item(txn);
      drive_transaction(txn);
      seq_item_port.item_done();
    end
  endtask

  virtual task drive_transaction(apb_transaction txn);
    @(posedge vif.pclk);
    // Setup phase
    vif.psel   <= 1'b1;
    vif.paddr  <= txn.addr;
    vif.pwrite <= txn.write;
    if (txn.write)
      vif.pwdata <= txn.data;
    vif.penable <= 1'b0;

    @(posedge vif.pclk);
    // Access phase
    vif.penable <= 1'b1;

    @(posedge vif.pclk);
    while (!vif.pready) @(posedge vif.pclk);

    if (!txn.write)
      txn.data = vif.prdata;

    // Idle
    vif.psel    <= 1'b0;
    vif.penable <= 1'b0;
  endtask
endclass
```

### Driver with Response

```systemverilog
virtual task run_phase(uvm_phase phase);
  apb_transaction req, rsp;
  forever begin
    seq_item_port.get_next_item(req);
    drive_transaction(req);

    // Send response back to sequence
    rsp = apb_transaction::type_id::create("rsp");
    rsp.set_id_info(req);  // Copy sequence/transaction IDs
    rsp.addr  = req.addr;
    rsp.data  = req.data;  // Contains read data if it was a read
    rsp.write = req.write;
    seq_item_port.item_done(rsp);
  end
endtask
```

---

## 10. uvm_monitor

`uvm_monitor` is a passive component that observes pin-level activity on the DUT interface and converts it into transactions. Unlike the driver, the monitor never drives signals — it only samples and broadcasts.

### Class Declaration

```systemverilog
class uvm_monitor extends uvm_component;
```

### Key Characteristics

- **Passive**: Never drives DUT signals.
- **Always present**: Active in both active and passive agents.
- **Broadcasts via analysis ports**: Sends observed transactions to scoreboards, coverage collectors, and other subscribers.

### Practical Example: APB Monitor

```systemverilog
class apb_monitor extends uvm_monitor;
  `uvm_component_utils(apb_monitor)

  virtual apb_if vif;
  uvm_analysis_port #(apb_transaction) ap;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ap = new("ap", this);
    if (!uvm_config_db#(virtual apb_if)::get(this, "", "vif", vif))
      `uvm_fatal("NOVIF", "Virtual interface not found")
  endfunction

  virtual task run_phase(uvm_phase phase);
    forever begin
      apb_transaction txn;
      collect_transaction(txn);
      ap.write(txn);  // Broadcast to all subscribers
    end
  endtask

  virtual task collect_transaction(output apb_transaction txn);
    txn = apb_transaction::type_id::create("mon_txn");

    // Wait for setup phase (PSEL asserted)
    @(posedge vif.pclk iff vif.psel);
    txn.addr  = vif.paddr;
    txn.write = vif.pwrite;
    if (txn.write)
      txn.data = vif.pwdata;

    // Wait for access phase completion
    @(posedge vif.pclk iff vif.penable);
    @(posedge vif.pclk iff vif.pready);
    if (!txn.write)
      txn.data = vif.prdata;

    `uvm_info(get_type_name(), $sformatf("Observed: %s", txn.convert2string()), UVM_HIGH)
  endtask
endclass
```

---

## 11. uvm_sequencer

`uvm_sequencer` manages the flow of sequence items between sequences and the driver. It implements an arbitration mechanism when multiple sequences compete for access.

### Class Declaration

```systemverilog
class uvm_sequencer #(type REQ = uvm_sequence_item,
                      type RSP = REQ) extends uvm_sequencer_param_base #(REQ, RSP);
```

### Inheritance Chain

```
uvm_component
  └── uvm_sequencer_base                  (arbitration, sequence management)
        └── uvm_sequencer_param_base      (parameterized with REQ/RSP types)
              └── uvm_sequencer           (final sequencer class)
```

### Built-in Members

| Member | Type | Description |
|---|---|---|
| `seq_item_export` | `uvm_seq_item_pull_imp #(REQ, RSP, this_type)` | Export connected to the driver's `seq_item_port` |

### Key Internal Methods

#### 11.1 Arbitration Control

| Method | Signature | Description |
|---|---|---|
| `set_arbitration` | `function void set_arbitration(uvm_sequencer_arb_mode val)` | Set the arbitration policy |
| `get_arbitration` | `function uvm_sequencer_arb_mode get_arbitration()` | Get the current policy |

Arbitration modes:

| Mode | Constant | Description |
|---|---|---|
| FIFO | `UVM_SEQ_ARB_FIFO` | First-come, first-served (default) |
| Weighted | `UVM_SEQ_ARB_WEIGHTED` | Random selection weighted by priority |
| Random | `UVM_SEQ_ARB_RANDOM` | Purely random selection |
| Strict FIFO | `UVM_SEQ_ARB_STRICT_FIFO` | Highest priority first, FIFO within same priority |
| Strict Random | `UVM_SEQ_ARB_STRICT_RANDOM` | Highest priority first, random within same priority |
| User | `UVM_SEQ_ARB_USER` | User-defined arbitration via `user_priority_arbitration` |

#### 11.2 Sequence Management

| Method | Signature | Description |
|---|---|---|
| `is_connected` | `function bit is_connected()` | Check if driver is connected |
| `has_do_available` | `function bit has_do_available()` | Check if any sequence item is available |
| `wait_for_sequences` | `task wait_for_sequences()` | Block until a sequence item becomes available |
| `stop_sequences` | `virtual function void stop_sequences()` | Kill all running sequences |
| `is_grabbed` | `function bit is_grabbed()` | Check if the sequencer is locked/grabbed |
| `current_grabber` | `function uvm_sequence_base current_grabber()` | Return the sequence that holds the lock |
| `is_blocked` | `function bit is_blocked(uvm_sequence_base seq)` | Check if a specific sequence is blocked |
| `lock` | `task lock(uvm_sequence_base seq)` | Grant exclusive access to a sequence |
| `unlock` | `function void unlock(uvm_sequence_base seq)` | Release exclusive access |
| `grab` | `task grab(uvm_sequence_base seq)` | Pre-emptive lock |
| `ungrab` | `function void ungrab(uvm_sequence_base seq)` | Release pre-emptive lock |

### Practical Example

```systemverilog
class apb_sequencer extends uvm_sequencer #(apb_transaction);
  `uvm_component_utils(apb_sequencer)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
endclass
```

In most cases the sequencer is used as-is with no additional logic. Custom arbitration or additional functionality can be added when needed.

### Sequencer with Custom Arbitration

```systemverilog
class priority_sequencer extends uvm_sequencer #(apb_transaction);
  `uvm_component_utils(priority_sequencer)

  function new(string name, uvm_component parent);
    super.new(name, parent);
    set_arbitration(UVM_SEQ_ARB_STRICT_FIFO);
  endfunction

  virtual function integer user_priority_arbitration(
    integer avail_sequences[$]
  );
    // Custom arbitration logic
    return avail_sequences[0];  // Always pick first available
  endfunction
endclass
```

---

## 12. uvm_agent

`uvm_agent` groups related components (driver, sequencer, monitor) into a single reusable unit. It can operate in **active** mode (with a driver and sequencer) or **passive** mode (monitor only).

### Class Declaration

```systemverilog
class uvm_agent extends uvm_component;
```

### Built-in Members

| Member | Type | Description |
|---|---|---|
| `is_active` | `uvm_active_passive_enum` | `UVM_ACTIVE` (default) or `UVM_PASSIVE` |

### Key Methods

| Method | Signature | Description |
|---|---|---|
| `new` | `function new(string name, uvm_component parent)` | Constructor |
| `get_is_active` | `function uvm_active_passive_enum get_is_active()` | Returns the active/passive setting |
| `build_phase` | Override | Construct driver, sequencer (if active), and monitor |
| `connect_phase` | Override | Connect driver's `seq_item_port` to sequencer's `seq_item_export` |

### Practical Example: Full APB Agent

```systemverilog
class apb_agent extends uvm_agent;
  `uvm_component_utils(apb_agent)

  apb_driver    drv;
  apb_sequencer sqr;
  apb_monitor   mon;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Monitor is always built
    mon = apb_monitor::type_id::create("mon", this);

    // Driver and sequencer only in active mode
    if (get_is_active() == UVM_ACTIVE) begin
      drv = apb_driver::type_id::create("drv", this);
      sqr = apb_sequencer::type_id::create("sqr", this);
    end
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    if (get_is_active() == UVM_ACTIVE) begin
      drv.seq_item_port.connect(sqr.seq_item_export);
    end
  endfunction
endclass
```

### Setting Active/Passive Mode from the Test

```systemverilog
// In the test's build_phase:
uvm_config_db#(int)::set(this, "env.agent", "is_active", UVM_PASSIVE);
```

---

## 13. uvm_scoreboard

`uvm_scoreboard` is a component that checks the DUT's output against expected results. UVM provides only a minimal base class; scoreboard logic is user-defined. The most common pattern uses `uvm_tlm_analysis_fifo` to collect transactions from monitors.

### Class Declaration

```systemverilog
class uvm_scoreboard extends uvm_component;
```

### Common Implementation Patterns

#### Pattern 1: Dual-Port Scoreboard with Analysis FIFOs

```systemverilog
class apb_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(apb_scoreboard)

  uvm_tlm_analysis_fifo #(apb_transaction) expected_fifo;
  uvm_tlm_analysis_fifo #(apb_transaction) actual_fifo;

  int match_count;
  int mismatch_count;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    expected_fifo = new("expected_fifo", this);
    actual_fifo   = new("actual_fifo", this);
  endfunction

  virtual task run_phase(uvm_phase phase);
    apb_transaction expected_txn, actual_txn;
    forever begin
      expected_fifo.get(expected_txn);
      actual_fifo.get(actual_txn);

      if (expected_txn.compare(actual_txn)) begin
        match_count++;
        `uvm_info(get_type_name(), "Transaction MATCH", UVM_MEDIUM)
      end else begin
        mismatch_count++;
        `uvm_error(get_type_name(),
          $sformatf("MISMATCH:\n  Expected: %s\n  Actual:   %s",
                    expected_txn.convert2string(),
                    actual_txn.convert2string()))
      end
    end
  endtask

  virtual function void check_phase(uvm_phase phase);
    super.check_phase(phase);
    if (mismatch_count > 0)
      `uvm_error(get_type_name(),
        $sformatf("Test FAILED: %0d mismatches", mismatch_count))
    else
      `uvm_info(get_type_name(),
        $sformatf("Test PASSED: %0d matches", match_count), UVM_LOW)
  endfunction
endclass
```

#### Pattern 2: In-Order Scoreboard Using uvm_in_order_comparator

```systemverilog
typedef uvm_in_order_comparator #(apb_transaction) apb_comparator;

class simple_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(simple_scoreboard)

  apb_comparator comparator;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    comparator = apb_comparator::type_id::create("comparator", this);
  endfunction
endclass
```

#### Pattern 3: Associative Array Reference Model

```systemverilog
class memory_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(memory_scoreboard)

  uvm_analysis_imp #(apb_transaction, memory_scoreboard) ap_imp;
  bit [31:0] memory_model[bit [31:0]];  // Address -> Data

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ap_imp = new("ap_imp", this);
  endfunction

  // Called automatically when a transaction arrives on the analysis port
  virtual function void write(apb_transaction txn);
    if (txn.write) begin
      memory_model[txn.addr] = txn.data;
      `uvm_info(get_type_name(),
        $sformatf("Stored: mem[0x%08h] = 0x%08h", txn.addr, txn.data),
        UVM_HIGH)
    end else begin
      if (memory_model.exists(txn.addr)) begin
        if (txn.data !== memory_model[txn.addr])
          `uvm_error(get_type_name(),
            $sformatf("Read mismatch at 0x%08h: expected 0x%08h, got 0x%08h",
                      txn.addr, memory_model[txn.addr], txn.data))
      end else begin
        `uvm_warning(get_type_name(),
          $sformatf("Read from uninitialized address 0x%08h", txn.addr))
      end
    end
  endfunction
endclass
```

---

## 14. uvm_env

`uvm_env` is a container component that assembles agents, scoreboards, coverage collectors, and other sub-environments into a complete verification environment.

### Class Declaration

```systemverilog
class uvm_env extends uvm_component;
```

### Practical Example

```systemverilog
class apb_env extends uvm_env;
  `uvm_component_utils(apb_env)

  apb_agent      agent;
  apb_scoreboard scoreboard;
  apb_coverage   coverage;
  apb_env_config cfg;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    if (!uvm_config_db#(apb_env_config)::get(this, "", "cfg", cfg))
      `uvm_fatal("NOCFG", "Environment config not found")

    // Pass down sub-configurations
    uvm_config_db#(int)::set(this, "agent", "is_active",
                              cfg.is_active ? UVM_ACTIVE : UVM_PASSIVE);
    uvm_config_db#(virtual apb_if)::set(this, "agent.*", "vif", cfg.vif);

    agent      = apb_agent::type_id::create("agent", this);
    scoreboard = apb_scoreboard::type_id::create("scoreboard", this);

    if (cfg.enable_coverage)
      coverage = apb_coverage::type_id::create("coverage", this);
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);

    // Connect monitor's analysis port to scoreboard
    agent.mon.ap.connect(scoreboard.actual_fifo.analysis_export);

    if (cfg.enable_coverage)
      agent.mon.ap.connect(coverage.analysis_export);
  endfunction
endclass
```

### Hierarchical Environments (SoC Level)

```systemverilog
class soc_env extends uvm_env;
  `uvm_component_utils(soc_env)

  apb_env  apb;
  axi_env  axi;
  uart_env uart;
  soc_scoreboard scoreboard;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    apb  = apb_env::type_id::create("apb", this);
    axi  = axi_env::type_id::create("axi", this);
    uart = uart_env::type_id::create("uart", this);
    scoreboard = soc_scoreboard::type_id::create("scoreboard", this);
  endfunction
endclass
```

---

## 15. uvm_test

`uvm_test` is the top-level component that configures the environment and launches sequences. Each test scenario is a separate class extending `uvm_test`.

### Class Declaration

```systemverilog
class uvm_test extends uvm_component;
```

### Key Responsibilities

1. Build and configure the environment.
2. Set factory overrides for the test.
3. Launch sequences in `run_phase`.
4. Manage phase objections.

### Practical Example

```systemverilog
class apb_base_test extends uvm_test;
  `uvm_component_utils(apb_base_test)

  apb_env env;
  apb_env_config env_cfg;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    env_cfg = apb_env_config::type_id::create("env_cfg");
    env_cfg.is_active = 1;
    env_cfg.enable_coverage = 1;

    if (!uvm_config_db#(virtual apb_if)::get(this, "", "vif", env_cfg.vif))
      `uvm_fatal("NOVIF", "No virtual interface in config DB")

    uvm_config_db#(apb_env_config)::set(this, "env", "cfg", env_cfg);

    env = apb_env::type_id::create("env", this);
  endfunction

  virtual function void end_of_elaboration_phase(uvm_phase phase);
    super.end_of_elaboration_phase(phase);
    uvm_top.print_topology();
  endfunction
endclass
```

### Specific Test Extending Base Test

```systemverilog
class apb_write_read_test extends apb_base_test;
  `uvm_component_utils(apb_write_read_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual task run_phase(uvm_phase phase);
    apb_rw_sequence seq;

    phase.raise_objection(this, "Starting write-read test");

    seq = apb_rw_sequence::type_id::create("seq");
    seq.start(env.agent.sqr);

    phase.drop_objection(this, "Write-read test complete");
  endtask
endclass
```

### Running a Specific Test

```
# Command-line argument to the simulator
+UVM_TESTNAME=apb_write_read_test
```

```systemverilog
// In the top-level testbench module:
module tb_top;
  apb_if apb_intf(clk, rst);

  // DUT instantiation
  apb_slave dut (.clk(clk), .rst(rst), /* ... */);

  initial begin
    uvm_config_db#(virtual apb_if)::set(null, "uvm_test_top", "vif", apb_intf);
    run_test();  // Picks up +UVM_TESTNAME from command line
  end
endmodule
```

---

## 16. UVM Phases In Detail

UVM simulation is divided into well-defined phases that execute in a specific order. Understanding phases is essential to writing correct UVM testbenches.

### Phase Execution Order

```
Time 0                                                    End of Simulation
  │                                                            │
  ▼                                                            ▼
┌──────────┐  Function phases (no time consumption)
│ build     │  Top-down: parent before children
├──────────┤
│ connect   │  Bottom-up: children before parent
├──────────┤
│ end_of_   │  Bottom-up
│ elabora-  │
│ tion      │
├──────────┤
│ start_of_ │  Bottom-up
│ simulation│
├──────────┤
│          │
│  run      │  All components execute in parallel (task-based, time-consuming)
│          │
│  ┌──────────────────────────────────────────────────┐
│  │  Runtime sub-phases (optional, inside run_phase): │
│  │  pre_reset → reset → post_reset →                │
│  │  pre_configure → configure → post_configure →    │
│  │  pre_main → main → post_main →                   │
│  │  pre_shutdown → shutdown → post_shutdown          │
│  └──────────────────────────────────────────────────┘
│          │
├──────────┤
│ extract   │  Bottom-up
├──────────┤
│ check     │  Bottom-up
├──────────┤
│ report    │  Bottom-up
├──────────┤
│ final     │  Top-down
└──────────┘
```

### Phase Details

#### Build Phase (Top-Down)

```systemverilog
virtual function void build_phase(uvm_phase phase);
  super.build_phase(phase);
  // 1. Get configuration from config_db
  // 2. Create sub-components using factory
  // 3. Set configuration for children
endfunction
```

- **Execution order**: Parent builds before children (top-down).
- **Why top-down**: Parents must create children, so they go first.
- **`super.build_phase`**: Calls `apply_config_settings` to apply field automation configs.

#### Connect Phase (Bottom-Up)

```systemverilog
virtual function void connect_phase(uvm_phase phase);
  super.connect_phase(phase);
  // Connect TLM ports, exports, analysis ports
  drv.seq_item_port.connect(sqr.seq_item_export);
  mon.ap.connect(sb.analysis_export);
endfunction
```

- **Execution order**: Children connect before parents (bottom-up).
- **Why bottom-up**: Ports on children must exist before parents connect them.

#### Run Phase (Parallel)

```systemverilog
virtual task run_phase(uvm_phase phase);
  phase.raise_objection(this);
  // Main simulation activity
  // This is a task — time passes here
  phase.drop_objection(this);
endtask
```

- **All components' `run_phase` tasks execute simultaneously** (forked in parallel).
- **Phase ends when all objections are dropped**.
- Uses the objection mechanism to control when simulation ends.

### Objection Mechanism

```systemverilog
// Raise: "I'm not done yet — don't end the phase"
phase.raise_objection(this, "reason string", count);

// Drop: "I'm done — phase can end when all objections are dropped"
phase.drop_objection(this, "reason string", count);

// Set drain time: extra delay after all objections drop
phase.get_objection().set_drain_time(this, 100ns);
```

### Phase Jumping

```systemverilog
// Jump to a different phase (rare, used for reset scenarios)
phase.jump(uvm_reset_phase::get());
```

---

## 17. UVM Factory

The UVM factory is a design pattern that centralizes object and component creation, enabling type overrides without modifying existing code. This is the foundation of UVM's reusability.

### How the Factory Works

```
                          ┌─────────────┐
                          │  UVM Factory│
                          │             │
  type_id::create() ─────►│  Override   │──────► Actual Object
                          │  Table      │
                          │             │
                          └─────────────┘

  1. User calls MyClass::type_id::create("name", parent)
  2. Factory checks override table
  3. If override exists, creates overridden type instead
  4. Returns handle (polymorphism via base class)
```

### Factory Registration

```systemverilog
// For uvm_object subclasses:
class my_transaction extends uvm_sequence_item;
  `uvm_object_utils(my_transaction)     // Registers with factory
  // ...
endclass

// For uvm_component subclasses:
class my_driver extends uvm_driver #(my_transaction);
  `uvm_component_utils(my_driver)       // Registers with factory
  // ...
endclass
```

### Creating Objects Through the Factory

```systemverilog
// CORRECT — uses factory (allows overrides)
my_transaction txn = my_transaction::type_id::create("txn");
my_driver drv = my_driver::type_id::create("drv", this);

// WRONG — bypasses factory (no overrides possible)
my_transaction txn = new("txn");
```

### Factory Key Methods

| Method | Context | Description |
|---|---|---|
| `type_id::create(name, parent)` | Static | Create an object/component through the factory |
| `set_type_override_by_type(orig, override)` | `uvm_factory` | Override all instances of `orig` with `override` |
| `set_inst_override_by_type(orig, override, path)` | `uvm_factory` | Override specific instance by hierarchical path |
| `set_type_override(orig_name, override_name)` | `uvm_factory` | String-based type override |
| `set_inst_override(orig_name, override_name, path)` | `uvm_factory` | String-based instance override |
| `print()` | `uvm_factory` | Print all registered types and overrides |
| `find_override_by_type` | `uvm_factory` | Look up what a type resolves to |
| `debug_create_by_type` | `uvm_factory` | Debug factory resolution |

### Override Examples

#### Type Override (Global)

```systemverilog
class apb_error_transaction extends apb_transaction;
  `uvm_object_utils(apb_error_transaction)

  constraint force_error_c {
    addr[31:28] == 4'hF;  // Invalid address range
  }

  function new(string name = "apb_error_transaction");
    super.new(name);
  endfunction
endclass

// In the test's build_phase:
virtual function void build_phase(uvm_phase phase);
  super.build_phase(phase);

  // Every apb_transaction::type_id::create() now returns apb_error_transaction
  apb_transaction::type_id::set_type_override(apb_error_transaction::get_type());
endfunction
```

#### Instance Override (Specific Path)

```systemverilog
virtual function void build_phase(uvm_phase phase);
  super.build_phase(phase);

  // Only override the driver in env.agent1
  set_inst_override_by_type(
    "env.agent1.drv",
    apb_driver::get_type(),
    apb_debug_driver::get_type()
  );
endfunction
```

#### Factory Debug

```systemverilog
// Print all registered types and overrides
uvm_factory::get().print();

// Or use the shorter form
factory.print();
```

---

## 18. UVM Configuration Database

`uvm_config_db` is a hierarchical key-value store that allows components to share configuration without hard-coded dependencies. It replaces the older `set_config_*` / `get_config_*` methods.

### API

```systemverilog
class uvm_config_db #(type T = int) extends uvm_resource_db #(T);

  // Store a value
  static function void set(
    uvm_component cntxt,     // Scope context (use 'this' or null for global)
    string        inst_name, // Hierarchical path relative to cntxt
    string        field_name,// Key name
    T             value      // Value to store
  );

  // Retrieve a value
  static function bit get(
    uvm_component cntxt,     // Scope context
    string        inst_name, // Hierarchical path relative to cntxt
    string        field_name,// Key name
    inout T       value      // Retrieved value (output)
  );
  // Returns 1 if found, 0 if not found

  // Check if a value exists
  static function bit exists(
    uvm_component cntxt,
    string        inst_name,
    string        field_name,
    bit           spell_chk = 0
  );

  // Wait for a value to be set
  static task wait_modified(
    uvm_component cntxt,
    string        inst_name,
    string        field_name
  );
endclass
```

### Common Usage Patterns

#### Passing Virtual Interfaces

```systemverilog
// In top-level module (before run_test):
initial begin
  uvm_config_db#(virtual apb_if)::set(
    null,               // null = global scope
    "uvm_test_top.*",   // Wildcard matches all components
    "vif",              // Key
    apb_intf            // Value (the actual interface instance)
  );
  run_test();
end

// In the driver's build_phase:
virtual function void build_phase(uvm_phase phase);
  super.build_phase(phase);
  if (!uvm_config_db#(virtual apb_if)::get(this, "", "vif", vif))
    `uvm_fatal("NOVIF", {"Virtual interface not found for ",
                          get_full_name(), ".vif"})
endfunction
```

#### Passing Configuration Objects

```systemverilog
class apb_agent_config extends uvm_object;
  `uvm_object_utils(apb_agent_config)

  uvm_active_passive_enum is_active = UVM_ACTIVE;
  bit enable_coverage = 1;
  int unsigned num_transactions = 100;

  function new(string name = "apb_agent_config");
    super.new(name);
  endfunction
endclass

// Set from test:
uvm_config_db#(apb_agent_config)::set(this, "env.agent", "cfg", agent_cfg);

// Get in agent:
uvm_config_db#(apb_agent_config)::get(this, "", "cfg", cfg);
```

#### Passing Scalar Values

```systemverilog
// Set an integer
uvm_config_db#(int)::set(this, "env.agent", "is_active", UVM_PASSIVE);

// Set a string
uvm_config_db#(string)::set(this, "env", "log_file", "sim.log");
```

### Scope Resolution Rules

The `set` call creates an entry visible to components matching `{cntxt.get_full_name(), ".", inst_name}`. The `get` call searches for entries matching `{cntxt.get_full_name(), ".", inst_name}`.

```
set(this, "agent.*", "vif", intf)
    │       │         │      │
    │       │         │      └── Value
    │       │         └── Field name (key)
    │       └── Instance path (relative to 'this', wildcard matches children)
    └── Context component

Effective scope: {this.get_full_name()}.agent.*
  e.g., "uvm_test_top.env.agent.*"
```

### Precedence Rules

When multiple `set` calls match a `get`:

1. **Higher context wins** (a set from a parent overrides one from a grandparent).
2. **Later set wins** (if same context level, last writer wins).
3. **More specific path wins** (exact match beats wildcard).

### Debug

```systemverilog
// Enable config DB tracing
uvm_config_db#(virtual apb_if)::set(/* ... */);

// Command-line debug:
+UVM_CONFIG_DB_TRACE
```

---

## 19. UVM TLM Ports and Communication

UVM's Transaction-Level Modeling (TLM) infrastructure provides a standardized way for components to communicate using abstract transactions rather than pin-level signals.

### Port Types

| Type | Direction | Description |
|---|---|---|
| **Port** (`uvm_*_port`) | Initiator → Target | Defines what the initiator wants to call |
| **Export** (`uvm_*_export`) | Passthrough | Forwards calls through hierarchy |
| **Imp** (`uvm_*_imp`) | Target implementation | Contains the actual `write()`, `get()`, etc. method |

### Communication Paradigms

#### 19.1 Analysis Ports (1-to-Many Broadcast)

The most common TLM pattern in UVM — a monitor broadcasts transactions to multiple subscribers.

```systemverilog
// In monitor:
uvm_analysis_port #(apb_transaction) ap;

function void build_phase(uvm_phase phase);
  ap = new("ap", this);
endfunction

task run_phase(uvm_phase phase);
  forever begin
    apb_transaction txn;
    // ... collect transaction ...
    ap.write(txn);  // Broadcast to ALL connected subscribers
  end
endtask
```

```systemverilog
// In subscriber (e.g., scoreboard):
uvm_analysis_imp #(apb_transaction, my_scoreboard) ap_imp;

function void build_phase(uvm_phase phase);
  ap_imp = new("ap_imp", this);
endfunction

function void write(apb_transaction txn);
  // Process the received transaction
endfunction
```

```systemverilog
// Connect in parent:
function void connect_phase(uvm_phase phase);
  monitor.ap.connect(scoreboard.ap_imp);
  monitor.ap.connect(coverage.ap_imp);   // Multiple subscribers
endfunction
```

#### 19.2 uvm_tlm_analysis_fifo

A buffered analysis subscriber — stores transactions for later retrieval.

```systemverilog
uvm_tlm_analysis_fifo #(apb_transaction) fifo;

function void build_phase(uvm_phase phase);
  fifo = new("fifo", this);
endfunction

function void connect_phase(uvm_phase phase);
  monitor.ap.connect(fifo.analysis_export);
endfunction

task run_phase(uvm_phase phase);
  apb_transaction txn;
  forever begin
    fifo.get(txn);  // Blocking — waits for a transaction
    // Process txn
  end
endtask
```

#### 19.3 Blocking Put/Get Ports

Point-to-point communication with blocking semantics.

```systemverilog
// Producer
class producer extends uvm_component;
  uvm_blocking_put_port #(apb_transaction) put_port;

  function void build_phase(uvm_phase phase);
    put_port = new("put_port", this);
  endfunction

  task run_phase(uvm_phase phase);
    apb_transaction txn = new("txn");
    put_port.put(txn);  // Blocks if consumer not ready
  endtask
endclass

// Consumer
class consumer extends uvm_component;
  uvm_blocking_put_imp #(apb_transaction, consumer) put_imp;

  function void build_phase(uvm_phase phase);
    put_imp = new("put_imp", this);
  endfunction

  task put(apb_transaction txn);
    // Process transaction
  endtask
endclass
```

#### 19.4 Multiple Analysis Imports with uvm_analysis_imp_decl

When a component needs to receive from multiple analysis ports:

```systemverilog
`uvm_analysis_imp_decl(_expected)
`uvm_analysis_imp_decl(_actual)

class my_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(my_scoreboard)

  uvm_analysis_imp_expected #(apb_transaction, my_scoreboard) expected_imp;
  uvm_analysis_imp_actual   #(apb_transaction, my_scoreboard) actual_imp;

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    expected_imp = new("expected_imp", this);
    actual_imp   = new("actual_imp", this);
  endfunction

  function void write_expected(apb_transaction txn);
    // Handle expected transaction
  endfunction

  function void write_actual(apb_transaction txn);
    // Handle actual transaction
  endfunction
endclass
```

### TLM Port Hierarchy Summary

```
                    ┌─────────┐
                    │  Port   │  (initiator — calls methods)
                    └────┬────┘
                         │
                    ┌────▼────┐
                    │ Export  │  (passthrough — hierarchical routing)
                    └────┬────┘
                         │
                    ┌────▼────┐
                    │   Imp   │  (target — implements methods)
                    └─────────┘

  Port → Port         ✗ Invalid
  Port → Export       ✓ (hierarchical)
  Port → Imp          ✓ (direct connection)
  Export → Export      ✓ (hierarchical chaining)
  Export → Imp         ✓ (final connection)
```

---

## 20. UVM Reporting and Messaging

UVM provides a comprehensive messaging system for reporting information, warnings, errors, and fatal conditions during simulation.

### Severity Levels

| Macro | Severity | Default Action | Description |
|---|---|---|---|
| `` `uvm_info(ID, MSG, VERBOSITY) `` | `UVM_INFO` | Display | Informational message |
| `` `uvm_warning(ID, MSG) `` | `UVM_WARNING` | Display | Warning — simulation continues |
| `` `uvm_error(ID, MSG) `` | `UVM_ERROR` | Display + Count | Error — simulation continues but test may fail |
| `` `uvm_fatal(ID, MSG) `` | `UVM_FATAL` | Display + Exit | Fatal — simulation terminates immediately |

### Verbosity Levels

| Level | Value | Usage |
|---|---|---|
| `UVM_NONE` | 0 | Always displayed |
| `UVM_LOW` | 100 | Important messages |
| `UVM_MEDIUM` | 200 | Default detail level |
| `UVM_HIGH` | 300 | Detailed messages |
| `UVM_FULL` | 400 | Very detailed |
| `UVM_DEBUG` | 500 | Debug-level detail |

### Usage Examples

```systemverilog
`uvm_info("DRIVER", "Driving transaction", UVM_MEDIUM)
`uvm_info("DRIVER", $sformatf("addr=0x%08h data=0x%08h", addr, data), UVM_HIGH)

`uvm_warning("TIMEOUT", "Transaction took longer than expected")

`uvm_error("MISMATCH", $sformatf("Expected 0x%08h, got 0x%08h", exp, act))

`uvm_fatal("NOVIF", "Virtual interface not found — cannot proceed")
```

### Controlling Verbosity

```systemverilog
// Programmatic:
set_report_verbosity_level(UVM_HIGH);
set_report_verbosity_level_hier(UVM_HIGH);  // This + all children

// Command-line:
+UVM_VERBOSITY=UVM_HIGH
+uvm_set_verbosity=<comp_path>,<id>,<verbosity>,<phase>
```

### Report Handlers and Actions

```systemverilog
// Change action for a specific ID
set_report_severity_action(UVM_ERROR, UVM_DISPLAY | UVM_COUNT);

// Demote errors to warnings for a specific ID
set_report_severity_id_override(UVM_ERROR, "EXPECTED_ERR", UVM_WARNING);

// Set max error count before fatal
set_report_max_quit_count(10);

// Route messages to a file
uvm_report_handler rh = get_report_handler();
int file_handle = $fopen("sim.log", "w");
set_report_default_file(file_handle);
set_report_severity_action(UVM_INFO, UVM_DISPLAY | UVM_LOG);
```

### Report Catcher (Advanced)

```systemverilog
class error_demote_catcher extends uvm_report_catcher;
  `uvm_object_utils(error_demote_catcher)

  function new(string name = "error_demote_catcher");
    super.new(name);
  endfunction

  virtual function action_e catch();
    if (get_severity() == UVM_ERROR && get_id() == "EXPECTED_ERR") begin
      set_severity(UVM_WARNING);
      return THROW;
    end
    return THROW;
  endfunction
endclass

// Install in test:
error_demote_catcher catcher = new();
uvm_report_cb::add(null, catcher);  // Global
```

---

## 21. UVM Register Layer (UVM RAL)

The UVM Register Abstraction Layer (RAL) provides a structured way to model, access, and verify hardware registers.

### RAL Class Hierarchy

```
uvm_object
├── uvm_reg_field       (individual register field)
├── uvm_reg             (single register, contains fields)
├── uvm_reg_block       (collection of registers and memories)
├── uvm_reg_map         (address map for a register block)
├── uvm_mem             (memory model)
├── uvm_reg_adapter     (converts register ops to bus transactions)
└── uvm_reg_predictor   (updates register model from observed transactions)
```

### Key RAL Classes and Methods

#### uvm_reg_field

| Method | Description |
|---|---|
| `configure(parent, size, lsb_pos, access, volatile, reset, has_reset, is_rand, individually_accessible)` | Configure the field |
| `set(value)` | Set the desired value |
| `get()` | Get the desired value |
| `get_mirrored_value()` | Get the mirrored (last known) value |
| `get_reset(kind)` | Get the reset value |

#### uvm_reg

| Method | Description |
|---|---|
| `configure(parent, regfile, hdl_path)` | Configure the register |
| `add_field(field)` | Add a field (done internally by field.configure) |
| `read(status, value, path, map, ...)` | Read the register (front-door or back-door) |
| `write(status, value, path, map, ...)` | Write to the register |
| `mirror(status, check, path, ...)` | Read and optionally compare with desired value |
| `update(status, path, ...)` | Write only if desired ≠ mirrored |
| `set(value)` | Set desired value (no bus access) |
| `get()` | Get desired value |
| `get_mirrored_value()` | Get mirrored value |
| `predict(value)` | Update the mirrored value without bus access |
| `reset(kind)` | Reset to reset value |
| `get_reset(kind)` | Get the reset value |
| `get_address(map)` | Get the register's address |

#### uvm_reg_block

| Method | Description |
|---|---|
| `configure(parent, hdl_path)` | Configure the block |
| `create_map(name, base_addr, n_bytes, endian, byte_addressing)` | Create an address map |
| `add_reg(reg, offset, rights, unmapped, frontdoor)` | Add a register to the default map |
| `lock_model()` | Lock the model (no further modifications) |
| `reset(kind)` | Reset all registers |
| `mirror(status, check, ...)` | Mirror all registers |
| `update(status, ...)` | Update all registers |
| `get_reg_by_name(name)` | Find a register by name |
| `get_reg_by_offset(offset, map)` | Find a register by offset |

### RAL Example

```systemverilog
// Register definition
class ctrl_reg extends uvm_reg;
  `uvm_object_utils(ctrl_reg)

  rand uvm_reg_field enable;
  rand uvm_reg_field mode;
  rand uvm_reg_field irq_mask;

  function new(string name = "ctrl_reg");
    super.new(name, 32, UVM_NO_COVERAGE);
  endfunction

  virtual function void build();
    enable   = uvm_reg_field::type_id::create("enable");
    mode     = uvm_reg_field::type_id::create("mode");
    irq_mask = uvm_reg_field::type_id::create("irq_mask");

    //              parent  size  lsb  access  volatile  reset  has_reset  rand  accessible
    enable.configure  (this,  1,    0,  "RW",   0,       1'b0,  1,         1,    0);
    mode.configure    (this,  2,    1,  "RW",   0,       2'b00, 1,         1,    0);
    irq_mask.configure(this,  8,    8,  "RW",   0,       8'hFF, 1,         1,    0);
  endfunction
endclass

// Register block
class my_reg_block extends uvm_reg_block;
  `uvm_object_utils(my_reg_block)

  rand ctrl_reg   ctrl;
  rand uvm_reg    status;
  uvm_reg_map     default_map;

  function new(string name = "my_reg_block");
    super.new(name, UVM_NO_COVERAGE);
  endfunction

  virtual function void build();
    ctrl = ctrl_reg::type_id::create("ctrl");
    ctrl.configure(this, null, "");
    ctrl.build();

    default_map = create_map("default_map", 'h0, 4, UVM_LITTLE_ENDIAN, 1);
    default_map.add_reg(ctrl, 'h00, "RW");

    lock_model();
  endfunction
endclass
```

### Register Adapter

```systemverilog
class apb_reg_adapter extends uvm_reg_adapter;
  `uvm_object_utils(apb_reg_adapter)

  function new(string name = "apb_reg_adapter");
    super.new(name);
    supports_byte_enable = 0;
    provides_responses   = 0;
  endfunction

  virtual function uvm_sequence_item reg2bus(const ref uvm_reg_bus_op rw);
    apb_transaction txn = apb_transaction::type_id::create("reg2bus_txn");
    txn.addr  = rw.addr;
    txn.write = (rw.kind == UVM_WRITE);
    txn.data  = rw.data;
    return txn;
  endfunction

  virtual function void bus2reg(uvm_sequence_item bus_item, ref uvm_reg_bus_op rw);
    apb_transaction txn;
    if (!$cast(txn, bus_item))
      `uvm_fatal("CAST", "bus2reg cast failed")
    rw.addr   = txn.addr;
    rw.data   = txn.data;
    rw.kind   = txn.write ? UVM_WRITE : UVM_READ;
    rw.status = UVM_IS_OK;
  endfunction
endclass
```

### Using RAL in a Test

```systemverilog
virtual task run_phase(uvm_phase phase);
  uvm_status_e status;
  uvm_reg_data_t read_data;

  phase.raise_objection(this);

  // Write using RAL
  reg_model.ctrl.write(status, 32'h0000_0105);

  // Read using RAL
  reg_model.ctrl.read(status, read_data);

  // Access individual fields
  reg_model.ctrl.enable.set(1);
  reg_model.ctrl.mode.set(2'b11);
  reg_model.ctrl.update(status);  // Write only changed fields

  // Mirror and check
  reg_model.ctrl.mirror(status, UVM_CHECK);

  phase.drop_objection(this);
endtask
```

---

## 22. UVM Field Automation Macros

Field automation macros automate the implementation of `do_copy`, `do_compare`, `do_print`, `do_pack`, `do_unpack`, and `do_record` for registered fields.

### Available Macros

| Macro | Data Type |
|---|---|
| `` `uvm_field_int(field, flags) `` | Integral types (bit, logic, int, etc.) |
| `` `uvm_field_string(field, flags) `` | `string` |
| `` `uvm_field_object(field, flags) `` | `uvm_object` subclasses |
| `` `uvm_field_enum(T, field, flags) `` | Enumerated types |
| `` `uvm_field_real(field, flags) `` | `real` |
| `` `uvm_field_event(field, flags) `` | `event` |
| `` `uvm_field_sarray_int(field, flags) `` | Static array of integrals |
| `` `uvm_field_array_int(field, flags) `` | Dynamic array of integrals |
| `` `uvm_field_queue_int(field, flags) `` | Queue of integrals |
| `` `uvm_field_aa_int_string(field, flags) `` | Associative array `int[string]` |
| `` `uvm_field_aa_string_int(field, flags) `` | Associative array `string[int]` |
| `` `uvm_field_array_object(field, flags) `` | Dynamic array of objects |
| `` `uvm_field_queue_object(field, flags) `` | Queue of objects |
| `` `uvm_field_array_string(field, flags) `` | Dynamic array of strings |
| `` `uvm_field_queue_string(field, flags) `` | Queue of strings |

### Flag Constants

| Flag | Hex Value | Description |
|---|---|---|
| `UVM_ALL_ON` | `'h000` | Enable all operations (default) |
| `UVM_COPY` | `'h001` | Include in copy |
| `UVM_NO_COPY` | `'h002` | Exclude from copy |
| `UVM_COMPARE` | `'h004` | Include in compare |
| `UVM_NO_COMPARE` | `'h008` | Exclude from compare |
| `UVM_PRINT` | `'h010` | Include in print |
| `UVM_NO_PRINT` | `'h020` | Exclude from print |
| `UVM_RECORD` | `'h040` | Include in record |
| `UVM_NO_RECORD` | `'h080` | Exclude from record |
| `UVM_PACK` | `'h100` | Include in pack |
| `UVM_NO_PACK` | `'h200` | Exclude from pack |

#### Radix Flags (for printing)

| Flag | Description |
|---|---|
| `UVM_BIN` | Binary |
| `UVM_DEC` | Decimal |
| `UVM_UNSIGNED` | Unsigned decimal |
| `UVM_HEX` | Hexadecimal (default) |
| `UVM_OCT` | Octal |
| `UVM_STRING` | String |
| `UVM_ENUM` | Enum name |

### Example: Field Automation

```systemverilog
typedef enum bit [1:0] {IDLE, READ, WRITE, ERROR} txn_type_e;

class my_transaction extends uvm_sequence_item;

  rand bit [31:0]  addr;
  rand bit [31:0]  data;
  rand txn_type_e  txn_type;
  rand bit [3:0]   byte_en;
  string           comment;

  `uvm_object_utils_begin(my_transaction)
    `uvm_field_int   (addr,     UVM_ALL_ON | UVM_HEX)
    `uvm_field_int   (data,     UVM_ALL_ON | UVM_HEX)
    `uvm_field_enum  (txn_type_e, txn_type, UVM_ALL_ON)
    `uvm_field_int   (byte_en,  UVM_ALL_ON | UVM_BIN)
    `uvm_field_string(comment,  UVM_ALL_ON | UVM_NO_COMPARE)
  `uvm_object_utils_end

  function new(string name = "my_transaction");
    super.new(name);
  endfunction
endclass
```

With this registration, all of the following work automatically:

```systemverilog
my_transaction t1, t2;
t1 = my_transaction::type_id::create("t1");
t2 = my_transaction::type_id::create("t2");

t1.randomize();
t2.copy(t1);              // Auto-copies all fields
t1.compare(t2);           // Auto-compares all fields (except comment)
t1.print();               // Auto-prints all fields with correct radix
bit stream[];
t1.pack(stream);          // Auto-serializes all fields
t2.unpack(stream);        // Auto-deserializes
```

> **Performance Note**: Field macros add runtime overhead due to string-based lookups. For high-performance testbenches, implement `do_copy`, `do_compare`, `do_print`, `do_pack`, and `do_unpack` manually.

---

## 23. UVM Callbacks

UVM callbacks allow you to inject additional behavior into existing components without modifying their source code, providing a complementary mechanism to the factory.

### Callback Infrastructure

```systemverilog
// Step 1: Define a callback class
class driver_callback extends uvm_callback;
  `uvm_object_utils(driver_callback)

  function new(string name = "driver_callback");
    super.new(name);
  endfunction

  virtual task pre_drive(apb_driver drv, apb_transaction txn);
    // Default: do nothing
  endtask

  virtual task post_drive(apb_driver drv, apb_transaction txn);
    // Default: do nothing
  endtask
endclass

// Step 2: Register callbacks with the component
class apb_driver extends uvm_driver #(apb_transaction);
  `uvm_component_utils(apb_driver)
  `uvm_register_cb(apb_driver, driver_callback)

  // ... constructor, build_phase ...

  virtual task run_phase(uvm_phase phase);
    apb_transaction txn;
    forever begin
      seq_item_port.get_next_item(txn);
      `uvm_do_callbacks(apb_driver, driver_callback, pre_drive(this, txn))
      drive_transaction(txn);
      `uvm_do_callbacks(apb_driver, driver_callback, post_drive(this, txn))
      seq_item_port.item_done();
    end
  endtask
endclass

// Step 3: Create a specific callback
class error_inject_callback extends driver_callback;
  `uvm_object_utils(error_inject_callback)

  function new(string name = "error_inject_callback");
    super.new(name);
  endfunction

  virtual task pre_drive(apb_driver drv, apb_transaction txn);
    // Inject address error
    txn.addr[31] = 1'b1;
    `uvm_info("CB", "Injected address error", UVM_MEDIUM)
  endtask
endclass

// Step 4: Install the callback in the test
class error_test extends apb_base_test;
  `uvm_component_utils(error_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    error_inject_callback cb = error_inject_callback::type_id::create("cb");
    uvm_callbacks#(apb_driver, driver_callback)::add(env.agent.drv, cb);
  endfunction
endclass
```

### Callback Methods

| Method | Class | Description |
|---|---|---|
| `add(comp, cb)` | `uvm_callbacks#(T, CB)` | Add a callback to a component |
| `add_by_name(name, cb, root)` | `uvm_callbacks#(T, CB)` | Add by hierarchical name pattern |
| `delete(comp, cb)` | `uvm_callbacks#(T, CB)` | Remove a callback |
| `display()` | `uvm_callbacks#(T, CB)` | Print all installed callbacks |

---

## 24. Complete UVM Testbench Example

Bringing everything together — a complete, minimal but functional UVM testbench for an APB slave device.

### Interface Definition

```systemverilog
interface apb_if(input logic pclk, input logic preset_n);
  logic        psel;
  logic        penable;
  logic        pwrite;
  logic [31:0] paddr;
  logic [31:0] pwdata;
  logic [31:0] prdata;
  logic        pready;
  logic        pslverr;

  // Clocking blocks for driver and monitor
  clocking driver_cb @(posedge pclk);
    output psel, penable, pwrite, paddr, pwdata;
    input  prdata, pready, pslverr;
  endclocking

  clocking monitor_cb @(posedge pclk);
    input psel, penable, pwrite, paddr, pwdata, prdata, pready, pslverr;
  endclocking

  modport driver_mp  (clocking driver_cb, input pclk, preset_n);
  modport monitor_mp (clocking monitor_cb, input pclk, preset_n);
endinterface
```

### Transaction

```systemverilog
class apb_transaction extends uvm_sequence_item;
  rand bit [31:0] addr;
  rand bit [31:0] data;
  rand bit        write;

  `uvm_object_utils_begin(apb_transaction)
    `uvm_field_int(addr,  UVM_ALL_ON | UVM_HEX)
    `uvm_field_int(data,  UVM_ALL_ON | UVM_HEX)
    `uvm_field_int(write, UVM_ALL_ON | UVM_BIN)
  `uvm_object_utils_end

  constraint addr_align_c { addr[1:0] == 2'b00; }
  constraint addr_range_c { addr inside {[32'h0000_0000 : 32'h0000_0FFF]}; }

  function new(string name = "apb_transaction");
    super.new(name);
  endfunction

  virtual function string convert2string();
    return $sformatf("%s addr=0x%08h data=0x%08h",
                     write ? "WR" : "RD", addr, data);
  endfunction
endclass
```

### Sequence

```systemverilog
class apb_base_sequence extends uvm_sequence #(apb_transaction);
  `uvm_object_utils(apb_base_sequence)

  function new(string name = "apb_base_sequence");
    super.new(name);
  endfunction

  virtual task body();
    apb_transaction txn;
    repeat (20) begin
      txn = apb_transaction::type_id::create("txn");
      start_item(txn);
      if (!txn.randomize())
        `uvm_fatal("RAND", "Randomization failed")
      finish_item(txn);
    end
  endtask
endclass
```

### Driver

```systemverilog
class apb_driver extends uvm_driver #(apb_transaction);
  `uvm_component_utils(apb_driver)

  virtual apb_if vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual apb_if)::get(this, "", "vif", vif))
      `uvm_fatal("NOVIF", "Virtual interface not set")
  endfunction

  virtual task run_phase(uvm_phase phase);
    // Wait for reset de-assertion
    @(posedge vif.preset_n);
    forever begin
      apb_transaction txn;
      seq_item_port.get_next_item(txn);
      drive(txn);
      seq_item_port.item_done();
    end
  endtask

  virtual task drive(apb_transaction txn);
    @(posedge vif.pclk);
    vif.psel    <= 1'b1;
    vif.paddr   <= txn.addr;
    vif.pwrite  <= txn.write;
    vif.pwdata  <= txn.write ? txn.data : '0;
    vif.penable <= 1'b0;

    @(posedge vif.pclk);
    vif.penable <= 1'b1;
    do @(posedge vif.pclk);
    while (!vif.pready);

    if (!txn.write)
      txn.data = vif.prdata;

    vif.psel    <= 1'b0;
    vif.penable <= 1'b0;
  endtask
endclass
```

### Monitor

```systemverilog
class apb_monitor extends uvm_monitor;
  `uvm_component_utils(apb_monitor)

  virtual apb_if vif;
  uvm_analysis_port #(apb_transaction) ap;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ap = new("ap", this);
    if (!uvm_config_db#(virtual apb_if)::get(this, "", "vif", vif))
      `uvm_fatal("NOVIF", "Virtual interface not set")
  endfunction

  virtual task run_phase(uvm_phase phase);
    forever begin
      apb_transaction txn;
      collect(txn);
      ap.write(txn);
    end
  endtask

  virtual task collect(output apb_transaction txn);
    txn = apb_transaction::type_id::create("mon_txn");
    @(posedge vif.pclk iff (vif.psel && !vif.penable));
    txn.addr  = vif.paddr;
    txn.write = vif.pwrite;
    if (txn.write) txn.data = vif.pwdata;
    @(posedge vif.pclk iff (vif.penable && vif.pready));
    if (!txn.write) txn.data = vif.prdata;
  endtask
endclass
```

### Sequencer, Agent, Environment, Test

```systemverilog
// ---- Sequencer ----
class apb_sequencer extends uvm_sequencer #(apb_transaction);
  `uvm_component_utils(apb_sequencer)
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
endclass

// ---- Agent ----
class apb_agent extends uvm_agent;
  `uvm_component_utils(apb_agent)

  apb_driver    drv;
  apb_sequencer sqr;
  apb_monitor   mon;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    mon = apb_monitor::type_id::create("mon", this);
    if (get_is_active() == UVM_ACTIVE) begin
      drv = apb_driver::type_id::create("drv", this);
      sqr = apb_sequencer::type_id::create("sqr", this);
    end
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    if (get_is_active() == UVM_ACTIVE)
      drv.seq_item_port.connect(sqr.seq_item_export);
  endfunction
endclass

// ---- Scoreboard ----
class apb_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(apb_scoreboard)

  uvm_analysis_imp #(apb_transaction, apb_scoreboard) ap_imp;
  bit [31:0] mem [bit [31:0]];
  int pass_count, fail_count;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ap_imp = new("ap_imp", this);
  endfunction

  virtual function void write(apb_transaction txn);
    if (txn.write) begin
      mem[txn.addr] = txn.data;
    end else begin
      if (mem.exists(txn.addr)) begin
        if (txn.data === mem[txn.addr]) pass_count++;
        else begin
          fail_count++;
          `uvm_error(get_type_name(), $sformatf(
            "Read mismatch @ 0x%08h: exp=0x%08h act=0x%08h",
            txn.addr, mem[txn.addr], txn.data))
        end
      end
    end
  endfunction

  virtual function void report_phase(uvm_phase phase);
    `uvm_info(get_type_name(), $sformatf(
      "Results: %0d passed, %0d failed", pass_count, fail_count), UVM_LOW)
  endfunction
endclass

// ---- Environment ----
class apb_env extends uvm_env;
  `uvm_component_utils(apb_env)

  apb_agent      agent;
  apb_scoreboard scoreboard;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    agent      = apb_agent::type_id::create("agent", this);
    scoreboard = apb_scoreboard::type_id::create("scoreboard", this);
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    agent.mon.ap.connect(scoreboard.ap_imp);
  endfunction
endclass

// ---- Test ----
class apb_base_test extends uvm_test;
  `uvm_component_utils(apb_base_test)

  apb_env env;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = apb_env::type_id::create("env", this);
  endfunction

  virtual function void end_of_elaboration_phase(uvm_phase phase);
    uvm_top.print_topology();
  endfunction

  virtual task run_phase(uvm_phase phase);
    apb_base_sequence seq;
    phase.raise_objection(this, "Running APB test");
    seq = apb_base_sequence::type_id::create("seq");
    seq.start(env.agent.sqr);
    #100ns;
    phase.drop_objection(this, "APB test complete");
  endtask
endclass
```

### Top-Level Testbench Module

```systemverilog
module tb_top;
  logic clk, rst_n;

  // Clock generation
  initial begin
    clk = 0;
    forever #5ns clk = ~clk;
  end

  // Reset
  initial begin
    rst_n = 0;
    #100ns;
    rst_n = 1;
  end

  // Interface
  apb_if apb_intf(.pclk(clk), .preset_n(rst_n));

  // DUT
  apb_slave_dut dut (
    .pclk    (clk),
    .preset_n(rst_n),
    .psel    (apb_intf.psel),
    .penable (apb_intf.penable),
    .pwrite  (apb_intf.pwrite),
    .paddr   (apb_intf.paddr),
    .pwdata  (apb_intf.pwdata),
    .prdata  (apb_intf.prdata),
    .pready  (apb_intf.pready),
    .pslverr (apb_intf.pslverr)
  );

  // UVM
  initial begin
    uvm_config_db#(virtual apb_if)::set(null, "uvm_test_top*", "vif", apb_intf);
    run_test();
  end
endmodule
```

---

## Quick Reference: UVM Macros Summary

| Macro | Purpose |
|---|---|
| `` `uvm_object_utils(T) `` | Register a `uvm_object` subclass with the factory |
| `` `uvm_component_utils(T) `` | Register a `uvm_component` subclass with the factory |
| `` `uvm_object_utils_begin(T) / `uvm_object_utils_end `` | Object registration with field automation |
| `` `uvm_component_utils_begin(T) / `uvm_component_utils_end `` | Component registration with field automation |
| `` `uvm_field_*(field, flags) `` | Register a field for automation |
| `` `uvm_info(ID, MSG, VERB) `` | Informational message |
| `` `uvm_warning(ID, MSG) `` | Warning message |
| `` `uvm_error(ID, MSG) `` | Error message |
| `` `uvm_fatal(ID, MSG) `` | Fatal message (exits simulation) |
| `` `uvm_do(item) `` | Create, randomize, and send a sequence item |
| `` `uvm_do_with(item, constraints) `` | `uvm_do` with inline constraints |
| `` `uvm_do_on(item, sequencer) `` | `uvm_do` on a specific sequencer |
| `` `uvm_do_on_with(item, seqr, constraints) `` | Combined |
| `` `uvm_do_pri(item, priority) `` | `uvm_do` with priority |
| `` `uvm_create(item) `` | Create only (no randomize/send) |
| `` `uvm_send(item) `` | Send without randomize |
| `` `uvm_rand_send(item) `` | Randomize and send |
| `` `uvm_rand_send_with(item, constraints) `` | Randomize with constraints and send |
| `` `uvm_declare_p_sequencer(SEQR) `` | Declare typed sequencer handle `p_sequencer` |
| `` `uvm_analysis_imp_decl(_suffix) `` | Declare suffixed analysis imp for multiple ports |
| `` `uvm_register_cb(T, CB) `` | Register callback type with component |
| `` `uvm_do_callbacks(T, CB, method) `` | Execute all registered callbacks |

---

## Quick Reference: Common Command-Line Arguments

| Argument | Description |
|---|---|
| `+UVM_TESTNAME=<test>` | Select which test to run |
| `+UVM_VERBOSITY=<level>` | Set global verbosity (UVM_NONE through UVM_DEBUG) |
| `+UVM_TIMEOUT=<ns>,YES` | Set simulation timeout |
| `+UVM_MAX_QUIT_COUNT=<n>,YES` | Max errors before fatal |
| `+UVM_CONFIG_DB_TRACE` | Enable config DB debug tracing |
| `+UVM_OBJECTION_TRACE` | Enable objection debug tracing |
| `+UVM_PHASE_TRACE` | Enable phase debug tracing |
| `+UVM_RESOURCE_DB_TRACE` | Enable resource DB debug tracing |
| `+uvm_set_verbosity=<path>,<id>,<verb>,<phase>` | Set per-component verbosity |
| `+uvm_set_config_int=<path>,<field>,<value>` | Set integer config from command line |
| `+uvm_set_config_string=<path>,<field>,<value>` | Set string config from command line |
| `+uvm_set_type_override=<orig>,<override>` | Factory type override from command line |
| `+uvm_set_inst_override=<path>,<orig>,<override>` | Factory instance override from command line |
