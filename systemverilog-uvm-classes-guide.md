# SystemVerilog Classes & UVM Internals — A Comprehensive Guide

A deep-dive tutorial covering SystemVerilog object-oriented programming and the internal architecture of the Universal Verification Methodology (UVM) library.

---

## Table of Contents

1. [Part I — SystemVerilog Class Fundamentals](#part-i--systemverilog-class-fundamentals)
   1. [What is a Class?](#1-what-is-a-class)
   2. [Properties and Methods](#2-properties-and-methods)
   3. [Object Lifetime — `new`, Handles, and `null`](#3-object-lifetime--new-handles-and-null)
   4. [The `this` Keyword](#4-the-this-keyword)
   5. [Encapsulation — `local` and `protected`](#5-encapsulation--local-and-protected)
   6. [Static Members](#6-static-members)
   7. [Inheritance and `extends`](#7-inheritance-and-extends)
   8. [Polymorphism and Virtual Methods](#8-polymorphism-and-virtual-methods)
   9. [Abstract Classes and Pure Virtual Methods](#9-abstract-classes-and-pure-virtual-methods)
   10. [Parameterized (Generic) Classes](#10-parameterized-generic-classes)
   11. [Shallow Copy, Deep Copy, and Cloning](#11-shallow-copy-deep-copy-and-cloning)
   12. [Randomization and Constraints](#12-randomization-and-constraints)
   13. [Typedef and Forward Declarations](#13-typedef-and-forward-declarations)
   14. [Packages and Class Scope Resolution](#14-packages-and-class-scope-resolution)
   15. [Interfacing Classes with Modules](#15-interfacing-classes-with-modules)
2. [Part II — UVM Class Hierarchy and Architecture](#part-ii--uvm-class-hierarchy-and-architecture)
   1. [UVM Class Tree Overview](#16-uvm-class-tree-overview)
   2. [`uvm_void` — The Root](#17-uvm_void--the-root)
   3. [`uvm_object` — Core Data Methods](#18-uvm_object--core-data-methods)
   4. [`uvm_transaction` and `uvm_sequence_item`](#19-uvm_transaction-and-uvm_sequence_item)
   5. [`uvm_component` — Hierarchy and Phases](#20-uvm_component--hierarchy-and-phases)
   6. [UVM Phases In Depth](#21-uvm-phases-in-depth)
   7. [The UVM Factory — `uvm_factory`](#22-the-uvm-factory--uvm_factory)
   8. [`uvm_config_db` — Configuration Database](#23-uvm_config_db--configuration-database)
   9. [TLM Ports and Communication](#24-tlm-ports-and-communication)
   10. [`uvm_driver` and `uvm_monitor`](#25-uvm_driver-and-uvm_monitor)
   11. [`uvm_sequencer` and `uvm_sequence`](#26-uvm_sequencer-and-uvm_sequence)
   12. [`uvm_agent`, `uvm_env`, and `uvm_test`](#27-uvm_agent-uvm_env-and-uvm_test)
   13. [`uvm_scoreboard` and Comparators](#28-uvm_scoreboard-and-comparators)
   14. [UVM Reporting — `uvm_report_object`](#29-uvm-reporting--uvm_report_object)
   15. [UVM Register Abstraction Layer (RAL)](#30-uvm-register-abstraction-layer-ral)
   16. [Field Macros vs. Do-Methods](#31-field-macros-vs-do-methods)
3. [Part III — Putting It All Together](#part-iii--putting-it-all-together)
   1. [Complete UVM Testbench Walk-through](#32-complete-uvm-testbench-walk-through)
   2. [Best Practices and Common Pitfalls](#33-best-practices-and-common-pitfalls)

---

# Part I — SystemVerilog Class Fundamentals

## 1. What is a Class?

A SystemVerilog **class** is a user-defined data type that bundles data (properties) and behaviour (methods) into a single unit. Unlike modules, classes are *dynamic* — they live on the heap, are created at run-time with `new`, and are garbage-collected when no handle points to them.

```systemverilog
class Packet;
  bit [7:0] addr;
  bit [31:0] data;
  bit        write;

  function void display();
    $display("Packet: addr=0x%0h data=0x%0h write=%0b", addr, data, write);
  endfunction
endclass
```

Key characteristics:

| Feature | Module | Class |
|---------|--------|-------|
| Allocation | Static (elaboration time) | Dynamic (run-time) |
| Hierarchy | Port-based connections | Handle-based references |
| Parameterization | `#(parameter ...)` | `#(type T = int)` |
| Inheritance | Not supported | `extends` keyword |
| Used for | RTL / structural design | Verification / testbench |

---

## 2. Properties and Methods

**Properties** are data members declared inside a class body. **Methods** are `function` and `task` members.

```systemverilog
class ALU_Transaction;
  // --- Properties ---
  rand  bit [3:0]  opcode;
  rand  bit [15:0] operand_a;
  rand  bit [15:0] operand_b;
        bit [31:0] result;
        bit        overflow;

  // --- Methods ---
  function bit [31:0] compute();
    case (opcode)
      4'h0: return operand_a + operand_b;
      4'h1: return operand_a - operand_b;
      4'h2: return operand_a & operand_b;
      4'h3: return operand_a | operand_b;
      default: return '0;
    endcase
  endfunction

  task drive(virtual alu_if vif);
    @(posedge vif.clk);
    vif.opcode    <= opcode;
    vif.operand_a <= operand_a;
    vif.operand_b <= operand_b;
  endtask
endclass
```

Methods declared inside the class body are *inline*. Methods can also be declared *out-of-body* using the scope resolution operator `::` (often used for large function bodies to keep the class declaration readable):

```systemverilog
class ALU_Transaction;
  // prototype
  extern function bit [31:0] compute();
endclass

function bit [31:0] ALU_Transaction::compute();
  // body here
endfunction
```

---

## 3. Object Lifetime — `new`, Handles, and `null`

A **handle** is a typed pointer to a class object. Declaring a handle does not create an object — the handle starts as `null`.

```systemverilog
Packet pkt;         // handle declared — initially null
pkt = new();        // object created on the heap, handle assigned

Packet pkt2 = pkt;  // pkt2 points to the SAME object (aliasing)

pkt = null;         // pkt no longer points to the object
                    // object is NOT freed yet — pkt2 still references it

pkt2 = null;        // now no handles point to the object → garbage collected
```

### Custom Constructors

The `new` function can accept arguments:

```systemverilog
class Packet;
  bit [7:0]  addr;
  bit [31:0] data;

  function new(bit [7:0] addr = 0, bit [31:0] data = 0);
    this.addr = addr;
    this.data = data;
  endfunction
endclass

// Usage
Packet p1 = new();                  // addr=0, data=0
Packet p2 = new(.addr(8'hFF));      // addr=0xFF, data=0
Packet p3 = new(8'h10, 32'hDEAD);  // addr=0x10, data=0xDEAD
```

---

## 4. The `this` Keyword

`this` refers to the current object instance. It is required when a method argument shadows a property name:

```systemverilog
class Register;
  bit [31:0] value;
  string     name;

  function new(string name, bit [31:0] value = 0);
    this.name  = name;   // this.name = property, name = argument
    this.value = value;
  endfunction
endclass
```

---

## 5. Encapsulation — `local` and `protected`

| Qualifier | Accessible from own class? | Accessible from subclass? | Accessible externally? |
|-----------|---------------------------|--------------------------|----------------------|
| *(default)* | Yes | Yes | Yes |
| `protected` | Yes | Yes | No |
| `local` | Yes | No | No |

```systemverilog
class SecurePacket;
  local      bit [127:0] encryption_key;   // only this class
  protected  bit [31:0]  header;           // this class + subclasses
             bit [31:0]  payload;          // anyone

  local function bit [127:0] get_key();
    return encryption_key;
  endfunction

  function void encrypt();
    payload = payload ^ get_key()[31:0];
  endfunction
endclass
```

---

## 6. Static Members

Static properties and methods belong to the **class itself**, not to individual objects. A common use is maintaining a count of created objects or providing utility functions.

```systemverilog
class Packet;
  static int unsigned count = 0;   // shared across all instances
  int unsigned id;

  function new();
    count++;
    id = count;
  endfunction

  static function int unsigned get_count();
    return count;
  endfunction
endclass

// Usage — no object needed for static access
initial begin
  Packet p1 = new();  // count = 1
  Packet p2 = new();  // count = 2
  $display("Total packets: %0d", Packet::get_count());  // prints 2
end
```

---

## 7. Inheritance and `extends`

A derived class **extends** a base class, inheriting all non-local properties and methods. Only single inheritance is supported in SystemVerilog.

```systemverilog
class Transaction;
  rand bit [7:0]  addr;
  rand bit [31:0] data;
  bit             status;

  function new(bit [7:0] addr = 0);
    this.addr = addr;
  endfunction

  virtual function void display();
    $display("[Transaction] addr=0x%0h data=0x%0h", addr, data);
  endfunction
endclass

class WriteTransaction extends Transaction;
  rand bit [3:0] byte_enable;

  function new(bit [7:0] addr = 0);
    super.new(addr);               // call parent constructor
    byte_enable = 4'hF;
  endfunction

  virtual function void display();
    super.display();               // call parent method first
    $display("  byte_enable=0b%04b", byte_enable);
  endfunction
endclass

class ReadTransaction extends Transaction;
  rand bit [1:0] burst_len;

  function new(bit [7:0] addr = 0);
    super.new(addr);
  endfunction

  virtual function void display();
    super.display();
    $display("  burst_len=%0d", burst_len);
  endfunction
endclass
```

### The `super` Keyword

- `super.new(...)` — calls the parent constructor. Must be the **first statement** in the child constructor (or is called implicitly with no arguments).
- `super.method_name(...)` — calls the parent's implementation of a method.

---

## 8. Polymorphism and Virtual Methods

Polymorphism allows a base-class handle to reference a derived-class object and invoke the correct (derived) method implementation at run-time. This requires the method to be declared `virtual`.

```systemverilog
class Animal;
  string name;

  function new(string name);
    this.name = name;
  endfunction

  virtual function void speak();
    $display("%s says: ...", name);
  endfunction
endclass

class Dog extends Animal;
  function new(string name);
    super.new(name);
  endfunction

  virtual function void speak();
    $display("%s says: Woof!", name);
  endfunction
endclass

class Cat extends Animal;
  function new(string name);
    super.new(name);
  endfunction

  virtual function void speak();
    $display("%s says: Meow!", name);
  endfunction
endclass

initial begin
  Animal animals[3];
  animals[0] = new("Generic");
  animals[1] = Dog::new("Rex");
  animals[2] = Cat::new("Whiskers");

  foreach (animals[i])
    animals[i].speak();  // dispatches to the correct override
end
```

Output:
```
Generic says: ...
Rex says: Woof!
Whiskers says: Meow!
```

### Dynamic Casting — `$cast`

When you need to access derived-class-specific members through a base-class handle:

```systemverilog
Transaction txn;
WriteTransaction wr_txn;

txn = new WriteTransaction(8'hAA);   // base handle → derived object

// Direct assignment fails at compile time:
// wr_txn = txn;  // ERROR

// Use $cast instead:
if ($cast(wr_txn, txn)) begin
  $display("byte_enable = 0x%0h", wr_txn.byte_enable);
end else begin
  $display("Cast failed — txn is not a WriteTransaction");
end
```

---

## 9. Abstract Classes and Pure Virtual Methods

A class with at least one `pure virtual` method is **abstract** — it cannot be instantiated directly.

```systemverilog
virtual class BusDriver;
  pure virtual task drive(input bit [31:0] data);
  pure virtual task read(output bit [31:0] data);

  virtual function void reset();
    $display("Default reset");
  endfunction
endclass

class AXI_Driver extends BusDriver;
  virtual axi_if vif;

  task drive(input bit [31:0] data);
    @(posedge vif.aclk);
    vif.awvalid <= 1;
    vif.wdata   <= data;
    // ... AXI protocol
  endtask

  task read(output bit [31:0] data);
    @(posedge vif.aclk);
    vif.arvalid <= 1;
    // ... AXI protocol
    data = vif.rdata;
  endtask
endclass
```

Attempting `BusDriver drv = new();` produces a compile-time error.

---

## 10. Parameterized (Generic) Classes

Classes can be parameterized by types or values, enabling reusable, type-safe containers:

```systemverilog
class FIFO #(type T = int, int DEPTH = 8);
  T queue[$];

  function void push(T item);
    if (queue.size() < DEPTH)
      queue.push_back(item);
    else
      $error("FIFO overflow");
  endfunction

  function T pop();
    if (queue.size() > 0)
      return queue.pop_front();
    else begin
      $error("FIFO underflow");
      return T'(0);
    end
  endfunction

  function int size();
    return queue.size();
  endfunction

  function bit is_empty();
    return (queue.size() == 0);
  endfunction

  function bit is_full();
    return (queue.size() >= DEPTH);
  endfunction
endclass

// Usage
FIFO #(bit [31:0], 16) data_fifo = new();
FIFO #(string, 4)      name_fifo = new();

initial begin
  data_fifo.push(32'hCAFEBABE);
  name_fifo.push("hello");
  $display("Data: 0x%0h", data_fifo.pop());
  $display("Name: %s", name_fifo.pop());
end
```

### Type Parameterization with Constraints

```systemverilog
class Scoreboard #(type T = Transaction);
  T expected_q[$];
  T actual_q[$];

  function void add_expected(T txn);
    expected_q.push_back(txn);
  endfunction

  function void add_actual(T txn);
    actual_q.push_back(txn);
  endfunction

  function bit compare();
    if (expected_q.size() != actual_q.size()) return 0;
    foreach (expected_q[i])
      if (!expected_q[i].compare(actual_q[i])) return 0;
    return 1;
  endfunction
endclass
```

---

## 11. Shallow Copy, Deep Copy, and Cloning

### Shallow Copy (Built-in)

The built-in `new` copy constructor creates a field-by-field copy. Handles inside the object are **not** deep-copied — both objects share the same referenced sub-objects.

```systemverilog
class Payload;
  bit [7:0] data[];

  function new(int size = 4);
    data = new[size];
  endfunction
endclass

class Packet;
  bit [7:0] addr;
  Payload   payload;   // handle to another object

  function new();
    payload = new(8);
  endfunction
endclass

initial begin
  Packet p1 = new();
  p1.addr = 8'hAA;
  p1.payload.data[0] = 8'h11;

  Packet p2 = new p1;             // SHALLOW copy
  p2.addr = 8'hBB;                // independent — p1.addr still 0xAA
  p2.payload.data[0] = 8'hFF;     // SHARED — p1.payload.data[0] is now 0xFF!
end
```

### Deep Copy (Manual)

```systemverilog
class Packet;
  bit [7:0] addr;
  Payload   payload;

  function new();
    payload = new(8);
  endfunction

  function Packet clone();
    clone = new();
    clone.addr = this.addr;
    clone.payload = new(this.payload.data.size());
    foreach (this.payload.data[i])
      clone.payload.data[i] = this.payload.data[i];
  endfunction
endclass
```

---

## 12. Randomization and Constraints

SystemVerilog's `rand` and `randc` qualifiers enable constrained-random stimulus generation:

```systemverilog
class EthernetFrame;
  rand  bit [47:0]  dst_mac;
  rand  bit [47:0]  src_mac;
  rand  bit [15:0]  ethertype;
  rand  bit [7:0]   payload[];
  randc bit [2:0]   priority;     // cyclic — exhausts all values before repeating

  // Constraints
  constraint c_payload_size {
    payload.size() inside {[46:1500]};   // IEEE 802.3 valid sizes
  }

  constraint c_ethertype {
    ethertype inside {16'h0800, 16'h0806, 16'h86DD};  // IPv4, ARP, IPv6
  }

  constraint c_no_broadcast {
    dst_mac != 48'hFFFF_FFFF_FFFF;
  }

  constraint c_payload_pattern {
    foreach (payload[i])
      payload[i] inside {[8'h20:8'h7E]};   // printable ASCII range
  }
endclass

initial begin
  EthernetFrame frame = new();

  // Basic randomization
  if (!frame.randomize())
    $fatal(1, "Randomization failed");

  // Inline constraint
  if (!frame.randomize() with {
    payload.size() == 64;
    dst_mac[47:24] == 24'h00_1A_2B;
  })
    $fatal(1, "Randomization failed");

  // Turn off a constraint
  frame.c_no_broadcast.constraint_mode(0);
  void'(frame.randomize());

  // Disable randomization for a field
  frame.dst_mac.rand_mode(0);
  frame.dst_mac = 48'hFFFF_FFFF_FFFF;
  void'(frame.randomize());
end
```

### Pre/Post Randomize Hooks

```systemverilog
class Packet;
  rand bit [7:0] addr;
  rand bit [7:0] data[];
  bit [15:0]     checksum;   // NOT rand — computed after randomization

  constraint c_size { data.size() inside {[1:16]}; }

  function void pre_randomize();
    $display("About to randomize packet");
  endfunction

  function void post_randomize();
    checksum = 0;
    foreach (data[i])
      checksum += data[i];
    checksum += addr;
  endfunction
endclass
```

### Distribution Constraints

```systemverilog
class Traffic;
  rand bit [1:0] pkt_type;

  constraint c_distribution {
    pkt_type dist {
      0 := 60,    // 60% normal
      1 := 20,    // 20% error
      2 := 15,    // 15% control
      3 := 5      //  5% management
    };
  }
endclass
```

### Implication and Conditional Constraints

```systemverilog
class AXI_Txn;
  rand bit        write;
  rand bit [7:0]  burst_len;
  rand bit [2:0]  burst_size;
  rand bit [1:0]  burst_type;

  constraint c_read_burst {
    !write -> burst_len inside {[0:15]};  // reads: max 16 beats
  }

  constraint c_write_burst {
    write -> burst_len inside {[0:255]}; // writes: up to 256 beats
  }

  constraint c_fixed_burst {
    burst_type == 0 -> burst_len == 0;   // FIXED burst: single beat
  }

  constraint c_wrap_power_of_2 {
    burst_type == 2 -> burst_len inside {1, 3, 7, 15};  // WRAP: power of 2
  }
endclass
```

---

## 13. Typedef and Forward Declarations

### Forward Declarations

When two classes reference each other, use `typedef class`:

```systemverilog
typedef class Response;  // forward declaration

class Request;
  int id;
  Response rsp;  // now legal — compiler knows Response is a class

  function void set_response(Response r);
    this.rsp = r;
  endfunction
endclass

class Response;
  int id;
  Request req;

  function new(Request req);
    this.req = req;
    this.id  = req.id;
  endfunction
endclass
```

### Typedef for Parameterized Class Shortcuts

```systemverilog
typedef FIFO #(bit [31:0], 256) DataFIFO;
typedef FIFO #(Packet, 64)      PacketFIFO;

DataFIFO   df = new();
PacketFIFO pf = new();
```

---

## 14. Packages and Class Scope Resolution

Classes are typically organized in **packages** for reuse:

```systemverilog
package bus_pkg;
  class Transaction;
    rand bit [31:0] addr;
    rand bit [31:0] data;
    rand bit        write;
    // ...
  endclass

  class Driver;
    virtual bus_if vif;
    // ...
  endclass
endpackage

// Import and use
module tb_top;
  import bus_pkg::*;

  initial begin
    Transaction txn = new();
    void'(txn.randomize());
  end
endmodule
```

---

## 15. Interfacing Classes with Modules

Classes live in the testbench domain. They communicate with RTL modules through **virtual interfaces**:

```systemverilog
interface bus_if(input logic clk);
  logic        valid;
  logic        ready;
  logic [31:0] addr;
  logic [31:0] data;
  logic        write;

  modport master(output valid, addr, data, write, input ready);
  modport slave (input  valid, addr, data, write, output ready);
endinterface

class BusDriver;
  virtual bus_if.master vif;   // virtual interface handle

  function new(virtual bus_if.master vif);
    this.vif = vif;
  endfunction

  task drive(Transaction txn);
    @(posedge vif.clk);
    vif.valid <= 1'b1;
    vif.addr  <= txn.addr;
    vif.data  <= txn.data;
    vif.write <= txn.write;
    @(posedge vif.clk);
    wait(vif.ready);
    vif.valid <= 1'b0;
  endtask
endclass
```

---

# Part II — UVM Class Hierarchy and Architecture

## 16. UVM Class Tree Overview

The UVM library is built on a carefully designed class hierarchy. Every UVM class ultimately inherits from `uvm_void`.

```
uvm_void
├── uvm_object
│   ├── uvm_transaction
│   │   └── uvm_sequence_item
│   ├── uvm_sequence #(REQ, RSP)
│   ├── uvm_reg_item
│   ├── uvm_reg_block
│   ├── uvm_reg
│   ├── uvm_reg_field
│   └── uvm_event
│
├── uvm_report_object
│   └── uvm_component
│       ├── uvm_driver #(REQ, RSP)
│       ├── uvm_monitor
│       ├── uvm_sequencer #(REQ, RSP)
│       ├── uvm_agent
│       ├── uvm_scoreboard
│       ├── uvm_env
│       ├── uvm_test
│       └── uvm_subscriber #(T)
│
└── uvm_port_base #(IF)
    ├── uvm_analysis_port #(T)
    ├── uvm_tlm_fifo #(T)
    └── ...
```

> **Note:** `uvm_report_object` is actually a subclass of `uvm_object` in the source tree. The diagram above simplifies the hierarchy for conceptual clarity.

---

## 17. `uvm_void` — The Root

`uvm_void` is an empty base class — it has **no properties and no methods**. Its sole purpose is to provide a common root from which all UVM objects and components descend, enabling a type-compatible top of the hierarchy.

```systemverilog
// From the UVM source (simplified)
virtual class uvm_void;
endclass
```

You will never instantiate or extend `uvm_void` directly. It exists so that framework utilities can accept any UVM type.

---

## 18. `uvm_object` — Core Data Methods

`uvm_object` is the foundation for all UVM data objects. It provides the critical "do" methods that enable printing, copying, comparing, packing, unpacking, and recording.

### Internal Methods of `uvm_object`

| Method | Purpose | Virtual Hook |
|--------|---------|-------------|
| `create()` | Factory-based object creation | Override via factory |
| `get_name()` | Return instance name | — |
| `get_full_name()` | Return hierarchical name | — |
| `get_type_name()` | Return class type as string | `do_*` not needed |
| `print()` | Print object fields | `do_print()` |
| `sprint()` | Return formatted string | `do_print()` |
| `copy()` | Copy from another object | `do_copy()` |
| `clone()` | Create + copy (deep clone) | `do_copy()` |
| `compare()` | Field-by-field comparison | `do_compare()` |
| `pack() / pack_bytes() / pack_ints()` | Serialize to bits/bytes/ints | `do_pack()` |
| `unpack() / unpack_bytes() / unpack_ints()` | Deserialize | `do_unpack()` |
| `record()` | Record to transaction database | `do_record()` |

### How the Do-Methods Work

Each public method (e.g., `copy()`) calls a corresponding `do_*` virtual method that you override. The public method handles boilerplate (null checks, type casting), then delegates to your custom logic:

```systemverilog
// Simplified internal flow of copy()
function void uvm_object::copy(uvm_object rhs);
  // 1. Null check
  if (rhs == null) begin
    `uvm_error("COPY", "Attempting to copy from null object")
    return;
  end
  // 2. Internal field copy (if using field macros)
  __m_uvm_field_automation(rhs, UVM_COPY, "");
  // 3. Call user-defined hook
  do_copy(rhs);
endfunction
```

### Implementing the Do-Methods — Full Example

```systemverilog
class APB_Transaction extends uvm_sequence_item;
  `uvm_object_utils(APB_Transaction)

  rand bit [31:0] addr;
  rand bit [31:0] data;
  rand bit        write;
  rand bit [3:0]  strobe;
       bit        slverr;

  function new(string name = "APB_Transaction");
    super.new(name);
  endfunction

  // --- do_copy ---
  virtual function void do_copy(uvm_object rhs);
    APB_Transaction rhs_;
    super.do_copy(rhs);        // always call super first
    if (!$cast(rhs_, rhs))
      `uvm_fatal("COPY", "Cast failed in do_copy")
    this.addr   = rhs_.addr;
    this.data   = rhs_.data;
    this.write  = rhs_.write;
    this.strobe = rhs_.strobe;
    this.slverr = rhs_.slverr;
  endfunction

  // --- do_compare ---
  virtual function bit do_compare(uvm_object rhs, uvm_comparer comparer);
    APB_Transaction rhs_;
    bit result;
    result = super.do_compare(rhs, comparer);
    if (!$cast(rhs_, rhs))
      return 0;
    result &= (this.addr   == rhs_.addr);
    result &= (this.data   == rhs_.data);
    result &= (this.write  == rhs_.write);
    result &= (this.strobe == rhs_.strobe);
    result &= (this.slverr == rhs_.slverr);
    return result;
  endfunction

  // --- do_print ---
  virtual function void do_print(uvm_printer printer);
    super.do_print(printer);
    printer.print_field_int("addr",   addr,   32, UVM_HEX);
    printer.print_field_int("data",   data,   32, UVM_HEX);
    printer.print_field_int("write",  write,   1, UVM_BIN);
    printer.print_field_int("strobe", strobe,  4, UVM_BIN);
    printer.print_field_int("slverr", slverr,  1, UVM_BIN);
  endfunction

  // --- do_pack / do_unpack ---
  virtual function void do_pack(uvm_packer packer);
    super.do_pack(packer);
    packer.pack_field_int(addr,   32);
    packer.pack_field_int(data,   32);
    packer.pack_field_int(write,   1);
    packer.pack_field_int(strobe,  4);
    packer.pack_field_int(slverr,  1);
  endfunction

  virtual function void do_unpack(uvm_packer packer);
    super.do_unpack(packer);
    addr   = packer.unpack_field_int(32);
    data   = packer.unpack_field_int(32);
    write  = packer.unpack_field_int(1);
    strobe = packer.unpack_field_int(4);
    slverr = packer.unpack_field_int(1);
  endfunction

  // --- convert2string ---
  virtual function string convert2string();
    return $sformatf("APB %s addr=0x%08h data=0x%08h strobe=0b%04b slverr=%0b",
                     write ? "WR" : "RD", addr, data, strobe, slverr);
  endfunction
endclass
```

---

## 19. `uvm_transaction` and `uvm_sequence_item`

### `uvm_transaction`

Extends `uvm_object` to add timing information:

| Method | Purpose |
|--------|---------|
| `accept_tr()` | Record acceptance time |
| `begin_tr()` | Record start time; begin transaction recording |
| `end_tr()` | Record end time; end transaction recording |
| `get_begin_time()` | Return start time |
| `get_end_time()` | Return end time |
| `get_accept_time()` | Return acceptance time |

### `uvm_sequence_item`

Extends `uvm_transaction` and adds sequencer-awareness:

| Method | Purpose |
|--------|---------|
| `set_sequencer()` | Associate with a sequencer |
| `get_sequencer()` | Return associated sequencer |
| `set_parent_sequence()` | Set the parent sequence |
| `get_parent_sequence()` | Get the parent sequence |
| `set_item_context()` | Set sequencer + parent in one call |
| `get_depth()` | Nesting depth of parent sequences |

Always extend `uvm_sequence_item` (not `uvm_transaction`) for stimulus items:

```systemverilog
class AHB_Transfer extends uvm_sequence_item;
  `uvm_object_utils(AHB_Transfer)

  rand bit [31:0] haddr;
  rand bit [31:0] hwdata;
  rand bit [2:0]  hsize;
  rand bit [2:0]  hburst;
  rand bit [1:0]  htrans;
  rand bit        hwrite;
       bit [31:0] hrdata;
       bit        hresp;

  constraint c_aligned {
    hsize == 3'b010 -> haddr[1:0] == 2'b00;  // word-aligned
    hsize == 3'b001 -> haddr[0]   == 1'b0;   // halfword-aligned
  }

  function new(string name = "AHB_Transfer");
    super.new(name);
  endfunction

  virtual function string convert2string();
    return $sformatf("AHB %s ADDR=0x%08h SIZE=%0d BURST=%0d DATA=0x%08h RESP=%0b",
                     hwrite ? "WR" : "RD", haddr, hsize, hburst,
                     hwrite ? hwdata : hrdata, hresp);
  endfunction
endclass
```

---

## 20. `uvm_component` — Hierarchy and Phases

`uvm_component` extends `uvm_report_object` (which extends `uvm_object`) and adds:

1. **Hierarchy management** — parent/child relationships forming a tree
2. **Phase execution** — automatic invocation of `build_phase`, `connect_phase`, etc.
3. **Configuration** — integration with `uvm_config_db`
4. **Factory support** — `type_id::create()` pattern

### Key Internal Methods

| Category | Methods |
|----------|---------|
| Hierarchy | `get_parent()`, `get_child()`, `get_children()`, `get_num_children()`, `get_full_name()` |
| Phases | `build_phase()`, `connect_phase()`, `run_phase()`, ... (see next section) |
| Factory | `create_component()`, `create_object()` |
| Configuration | `set_config_*()`, `get_config_*()` (deprecated; use `uvm_config_db`) |
| Reporting | `uvm_report_info()`, `uvm_report_warning()`, `uvm_report_error()`, `uvm_report_fatal()` |

### Constructor Signature

Every `uvm_component` subclass must accept `(string name, uvm_component parent)`:

```systemverilog
class my_monitor extends uvm_monitor;
  `uvm_component_utils(my_monitor)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
endclass
```

---

## 21. UVM Phases In Depth

UVM executes verification through a phased execution model. The phases run automatically in a defined order once `run_test()` is called.

### Phase Execution Order

```
BUILD PHASES (top-down)
 ├─ build_phase         → Create sub-components, configure
 ├─ connect_phase       → Connect TLM ports, exports
 └─ end_of_elaboration_phase → Final adjustments, topology display

RUN PHASES (all run in parallel via fork-join, bottom-up start)
 ├─ start_of_simulation_phase  → Print banner, final config
 ├─ run_phase                  → Main simulation (task — consumes time)
 │   ├─ reset_phase            ─┐
 │   ├─ configure_phase         │ Fine-grained runtime
 │   ├─ main_phase              │ sub-phases (optional)
 │   ├─ shutdown_phase          ─┘
 └─ (objections control when run_phase ends)

CLEANUP PHASES (bottom-up)
 ├─ extract_phase       → Pull data from DUT / scoreboards
 ├─ check_phase         → Verify results, report errors
 └─ report_phase        → Generate summary reports

 └─ final_phase         → Close files, release resources
```

### Phase Implementation

```systemverilog
class my_agent extends uvm_agent;
  `uvm_component_utils(my_agent)

  my_driver    drv;
  my_sequencer sqr;
  my_monitor   mon;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  // BUILD PHASE — create sub-components
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (get_is_active() == UVM_ACTIVE) begin
      drv = my_driver::type_id::create("drv", this);
      sqr = my_sequencer::type_id::create("sqr", this);
    end
    mon = my_monitor::type_id::create("mon", this);
  endfunction

  // CONNECT PHASE — wire up ports
  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    if (get_is_active() == UVM_ACTIVE)
      drv.seq_item_port.connect(sqr.seq_item_export);
  endfunction

  // RUN PHASE (task) — simulation activity
  virtual task run_phase(uvm_phase phase);
    // Usually empty in agents — activity is in driver/sequences
  endtask
endclass
```

### Objection Mechanism

The `run_phase` (and its sub-phases) are tasks that consume simulation time. UVM uses an **objection mechanism** to determine when a phase should end:

```systemverilog
class my_test extends uvm_test;
  `uvm_component_utils(my_test)

  my_env env;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = my_env::type_id::create("env", this);
  endfunction

  virtual task run_phase(uvm_phase phase);
    my_sequence seq = my_sequence::type_id::create("seq");

    phase.raise_objection(this, "Starting test sequence");
    seq.start(env.agent.sqr);
    phase.drop_objection(this, "Test sequence complete");
  endtask
endclass
```

When all objections are dropped, the phase ends. If no objections are ever raised, the phase completes immediately.

---

## 22. The UVM Factory — `uvm_factory`

The factory is the mechanism that enables **type overrides** without modifying source code — critical for reuse and configurability.

### How It Works Internally

1. **Registration** — The `` `uvm_object_utils `` / `` `uvm_component_utils `` macros register a class with the factory by creating a `type_id` proxy class.
2. **Creation** — `type_id::create()` asks the factory to construct an object. The factory checks for overrides and returns the appropriate type.
3. **Override** — Before creation, you can install type or instance overrides.

### Registration Macro Expansion (Simplified)

When you write:

```systemverilog
class my_driver extends uvm_driver #(my_txn);
  `uvm_component_utils(my_driver)
  // ...
endclass
```

The macro expands to approximately:

```systemverilog
class my_driver extends uvm_driver #(my_txn);
  typedef uvm_component_registry #(my_driver, "my_driver") type_id;

  static function type_id get_type();
    return type_id::get();
  endfunction

  virtual function uvm_object_wrapper get_object_type();
    return type_id::get();
  endfunction

  virtual function string get_type_name();
    return "my_driver";
  endfunction

  // ...
endclass
```

### Factory Creation

```systemverilog
// Always use create(), never use new() for UVM classes
my_driver drv;
drv = my_driver::type_id::create("drv", this);
```

### Type Overrides

```systemverilog
class my_test extends uvm_test;
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Override: wherever my_driver would be created, create enhanced_driver instead
    my_driver::type_id::set_type_override(enhanced_driver::get_type());

    // Instance override: only override a specific instance
    my_driver::type_id::set_inst_override(
      debug_driver::get_type(),
      "env.agent.drv"   // hierarchical path
    );

    env = my_env::type_id::create("env", this);
  endfunction
endclass
```

### Factory Override with `set_type_override_by_type`

```systemverilog
// At the test level
virtual function void build_phase(uvm_phase phase);
  super.build_phase(phase);

  // Override transaction type globally
  set_type_override_by_type(
    base_txn::get_type(),
    error_injection_txn::get_type()
  );
endfunction
```

---

## 23. `uvm_config_db` — Configuration Database

`uvm_config_db` is a parameterized static class that provides a global configuration store, organized hierarchically.

### Internal Architecture

`uvm_config_db` is built on top of `uvm_resource_db`. Each entry has:
- A **context** (hierarchical scope)
- A **field name** (string key)
- A **value** (parameterized type)

### API

```systemverilog
// SET a configuration value
uvm_config_db #(type)::set(
  uvm_component context,   // scope (usually "this" or null)
  string        inst_name,  // target instance path (glob patterns allowed)
  string        field_name, // key
  type          value       // the value to store
);

// GET a configuration value
uvm_config_db #(type)::get(
  uvm_component context,   // scope (usually "this" or null)
  string        inst_name,  // instance path ("" for current component)
  string        field_name, // key
  ref type      value       // output
);
// Returns 1 on success, 0 if not found
```

### Usage Patterns

```systemverilog
// In the test: pass virtual interface down to all components
class my_test extends uvm_test;
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Pass interface to all components under env.agent.*
    uvm_config_db #(virtual bus_if)::set(this, "env.agent.*", "vif", tb_top.bus_if_inst);

    // Pass configuration object
    my_agent_config cfg = new("cfg");
    cfg.is_active = UVM_ACTIVE;
    cfg.has_coverage = 1;
    uvm_config_db #(my_agent_config)::set(this, "env.agent", "cfg", cfg);
  endfunction
endclass

// In the driver: retrieve the virtual interface
class my_driver extends uvm_driver #(my_txn);
  virtual bus_if vif;

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(virtual bus_if)::get(this, "", "vif", vif))
      `uvm_fatal("NOVIF", "Virtual interface not found in config_db")
  endfunction
endclass
```

### Wildcards and Precedence

- `"*"` matches any instance path segment
- More specific paths take precedence over less specific ones
- Later `set()` calls override earlier ones at the same specificity

---

## 24. TLM Ports and Communication

UVM uses **Transaction Level Modeling (TLM)** for inter-component communication. This decouples components and enables reuse.

### Port Types

| Port | Direction | Description |
|------|-----------|-------------|
| `uvm_analysis_port #(T)` | Producer → N consumers | Broadcast (non-blocking) |
| `uvm_analysis_imp #(T, IMP)` | Receives from analysis port | Implementation in consumer |
| `uvm_blocking_put_port #(T)` | Push-based | Blocking put |
| `uvm_blocking_get_port #(T)` | Pull-based | Blocking get |
| `uvm_seq_item_pull_port #(REQ, RSP)` | Driver ↔ Sequencer | Sequence item handshake |
| `uvm_tlm_analysis_fifo #(T)` | FIFO buffer | Buffered analysis |

### Analysis Port Pattern (Most Common)

```systemverilog
// PRODUCER (monitor) — broadcasts transactions
class my_monitor extends uvm_monitor;
  `uvm_component_utils(my_monitor)

  uvm_analysis_port #(my_txn) ap;   // analysis port

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ap = new("ap", this);
  endfunction

  virtual task run_phase(uvm_phase phase);
    my_txn txn;
    forever begin
      // ... observe DUT signals, collect into txn ...
      txn = my_txn::type_id::create("txn");
      // ... populate txn from interface signals ...
      ap.write(txn);   // broadcast to all connected subscribers
    end
  endtask
endclass

// CONSUMER (scoreboard) — receives transactions
class my_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(my_scoreboard)

  uvm_analysis_imp #(my_txn, my_scoreboard) ap_imp;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ap_imp = new("ap_imp", this);
  endfunction

  // This function is called every time a transaction is written to the port
  virtual function void write(my_txn txn);
    `uvm_info("SCB", $sformatf("Received: %s", txn.convert2string()), UVM_MEDIUM)
    // ... check logic ...
  endfunction
endclass
```

### Connecting Ports (in the environment)

```systemverilog
class my_env extends uvm_env;
  my_agent      agent;
  my_scoreboard scb;

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    agent.mon.ap.connect(scb.ap_imp);
  endfunction
endclass
```

### Analysis FIFO (for multiple ports or buffering)

When a component needs to receive from multiple analysis ports:

```systemverilog
class my_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(my_scoreboard)

  uvm_tlm_analysis_fifo #(my_txn) expected_fifo;
  uvm_tlm_analysis_fifo #(my_txn) actual_fifo;

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    expected_fifo = new("expected_fifo", this);
    actual_fifo   = new("actual_fifo", this);
  endfunction

  virtual task run_phase(uvm_phase phase);
    my_txn expected_txn, actual_txn;
    forever begin
      expected_fifo.get(expected_txn);
      actual_fifo.get(actual_txn);
      if (!expected_txn.compare(actual_txn))
        `uvm_error("MISMATCH", $sformatf("Expected: %s\nActual: %s",
                   expected_txn.convert2string(), actual_txn.convert2string()))
      else
        `uvm_info("MATCH", "Transaction matched", UVM_HIGH)
    end
  endtask
endclass

// Connection
class my_env extends uvm_env;
  virtual function void connect_phase(uvm_phase phase);
    ref_model.ap.connect(scb.expected_fifo.analysis_export);
    agent.mon.ap.connect(scb.actual_fifo.analysis_export);
  endfunction
endclass
```

---

## 25. `uvm_driver` and `uvm_monitor`

### `uvm_driver #(REQ, RSP)`

The driver converts sequence items into pin-level activity. It has a built-in TLM port (`seq_item_port`) that communicates with the sequencer.

#### Internal Methods and Flow

```
                    Sequencer                          Driver
                  ┌──────────┐                      ┌──────────┐
 Sequence ───────>│ FIFO     │  seq_item_port       │          │
                  │          │<─────────────────────>│  drive() │──> DUT
                  │          │  get_next_item()      │          │
                  │          │  item_done()          │          │
                  └──────────┘                      └──────────┘
```

```systemverilog
class apb_driver extends uvm_driver #(APB_Transaction);
  `uvm_component_utils(apb_driver)

  virtual apb_if vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(virtual apb_if)::get(this, "", "vif", vif))
      `uvm_fatal("NOVIF", "No virtual interface for APB driver")
  endfunction

  virtual task run_phase(uvm_phase phase);
    APB_Transaction txn;
    forever begin
      seq_item_port.get_next_item(txn);    // blocking: wait for sequence item
      drive_transaction(txn);
      seq_item_port.item_done();           // signal completion to sequencer
    end
  endtask

  virtual task drive_transaction(APB_Transaction txn);
    @(posedge vif.pclk);
    vif.psel    <= 1'b1;
    vif.penable <= 1'b0;
    vif.paddr   <= txn.addr;
    vif.pwrite  <= txn.write;
    if (txn.write)
      vif.pwdata <= txn.data;

    @(posedge vif.pclk);
    vif.penable <= 1'b1;

    @(posedge vif.pclk);
    while (!vif.pready) @(posedge vif.pclk);

    if (!txn.write)
      txn.data = vif.prdata;
    txn.slverr = vif.pslverr;

    vif.psel    <= 1'b0;
    vif.penable <= 1'b0;
  endtask
endclass
```

### Alternative Driver Patterns

```systemverilog
// Pattern 2: try_next_item (non-blocking — drive idle when no items)
virtual task run_phase(uvm_phase phase);
  APB_Transaction txn;
  forever begin
    seq_item_port.try_next_item(txn);
    if (txn != null) begin
      drive_transaction(txn);
      seq_item_port.item_done();
    end else begin
      drive_idle();
    end
  end
endtask

// Pattern 3: get (simplified — no item_done needed)
virtual task run_phase(uvm_phase phase);
  APB_Transaction txn;
  forever begin
    seq_item_port.get(txn);     // combines get_next_item + item_done
    drive_transaction(txn);
  end
endtask
```

### `uvm_monitor`

Monitors are passive — they observe DUT signals without driving them. `uvm_monitor` extends `uvm_component` directly (no extra built-in ports).

```systemverilog
class apb_monitor extends uvm_monitor;
  `uvm_component_utils(apb_monitor)

  virtual apb_if vif;
  uvm_analysis_port #(APB_Transaction) ap;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ap = new("ap", this);
    if (!uvm_config_db #(virtual apb_if)::get(this, "", "vif", vif))
      `uvm_fatal("NOVIF", "No virtual interface for APB monitor")
  endfunction

  virtual task run_phase(uvm_phase phase);
    APB_Transaction txn;
    forever begin
      collect_transaction(txn);
      ap.write(txn);
    end
  endtask

  virtual task collect_transaction(output APB_Transaction txn);
    txn = APB_Transaction::type_id::create("txn");

    @(posedge vif.pclk);
    wait(vif.psel && !vif.penable);  // setup phase

    txn.addr  = vif.paddr;
    txn.write = vif.pwrite;
    if (txn.write)
      txn.data = vif.pwdata;

    @(posedge vif.pclk);  // access phase
    wait(vif.pready);

    if (!txn.write)
      txn.data = vif.prdata;
    txn.slverr = vif.pslverr;

    `uvm_info("MON", $sformatf("Collected: %s", txn.convert2string()), UVM_HIGH)
  endtask
endclass
```

---

## 26. `uvm_sequencer` and `uvm_sequence`

### `uvm_sequencer #(REQ, RSP)`

The sequencer is an **arbitration hub** between sequences and the driver. It manages:
- A FIFO of sequence items from one or more running sequences
- Arbitration policy when multiple sequences compete
- Lock/grab semantics for exclusive access

Key internal mechanisms:

| Method / Property | Purpose |
|-------------------|---------|
| `seq_item_export` | TLM export connected to driver's `seq_item_port` |
| `set_arbitration(UVM_SEQ_ARB_*)` | Set arbitration mode (FIFO, random, weighted, etc.) |
| `lock()` / `unlock()` | Exclusive sequencer access for a sequence |
| `grab()` / `ungrab()` | Higher-priority exclusive access |
| `is_blocked()` | Check if a sequence is blocked |

```systemverilog
class apb_sequencer extends uvm_sequencer #(APB_Transaction);
  `uvm_component_utils(apb_sequencer)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
endclass
```

### `uvm_sequence #(REQ, RSP)`

A sequence generates a stream of sequence items. It extends `uvm_sequence_item` (and thus `uvm_object`), meaning sequences are objects, not components.

#### Internal Execution Flow

```
 ┌──────────────────────────────────────────────────────┐
 │                  sequence.start(sqr)                 │
 │                         │                            │
 │                    ┌────▼────┐                       │
 │                    │ body()  │  ← user overrides     │
 │                    └────┬────┘                       │
 │         ┌───────────────┼───────────────┐            │
 │         ▼               ▼               ▼            │
 │   start_item(req) start_item(req) start_item(req)   │
 │         │               │               │            │
 │   finish_item(req) finish_item(req) finish_item(req) │
 │         │               │               │            │
 │    (sent to driver via sequencer arbitration)        │
 └──────────────────────────────────────────────────────┘
```

#### Key Methods

| Method | Purpose |
|--------|---------|
| `body()` | Override to define the sequence behavior |
| `start(sequencer, parent_seq)` | Launch the sequence on a sequencer |
| `start_item(item)` | Request arbitration from sequencer |
| `finish_item(item)` | Send item to driver, wait for `item_done()` |
| `get_response(rsp)` | Get response from driver (optional) |
| `pre_body()` / `post_body()` | Hooks before/after `body()` |
| `pre_do()` / `mid_do()` / `post_do()` | Fine-grained hooks around each item |

### Sequence Examples

```systemverilog
// Basic write sequence
class apb_write_seq extends uvm_sequence #(APB_Transaction);
  `uvm_object_utils(apb_write_seq)

  rand bit [31:0] addr;
  rand bit [31:0] data;

  function new(string name = "apb_write_seq");
    super.new(name);
  endfunction

  virtual task body();
    APB_Transaction txn = APB_Transaction::type_id::create("txn");
    start_item(txn);
    if (!txn.randomize() with {
      txn.addr  == local::addr;
      txn.data  == local::data;
      txn.write == 1;
    })
      `uvm_fatal("RAND", "Randomization failed")
    finish_item(txn);
  endtask
endclass

// Burst read sequence
class apb_burst_read_seq extends uvm_sequence #(APB_Transaction);
  `uvm_object_utils(apb_burst_read_seq)

  rand int unsigned num_reads;
  rand bit [31:0]   base_addr;

  constraint c_default {
    num_reads inside {[1:16]};
    base_addr[1:0] == 0;
  }

  function new(string name = "apb_burst_read_seq");
    super.new(name);
  endfunction

  virtual task body();
    APB_Transaction txn;
    for (int i = 0; i < num_reads; i++) begin
      txn = APB_Transaction::type_id::create($sformatf("txn_%0d", i));
      start_item(txn);
      if (!txn.randomize() with {
        txn.addr  == local::base_addr + (i * 4);
        txn.write == 0;
      })
        `uvm_fatal("RAND", "Randomization failed")
      finish_item(txn);
      `uvm_info("SEQ", $sformatf("Read[%0d]: addr=0x%08h data=0x%08h",
                i, txn.addr, txn.data), UVM_MEDIUM)
    end
  endtask
endclass

// Virtual sequence (orchestrates multiple sequences on multiple sequencers)
class top_virtual_seq extends uvm_sequence #(uvm_sequence_item);
  `uvm_object_utils(top_virtual_seq)

  apb_sequencer apb_sqr;
  axi_sequencer axi_sqr;

  function new(string name = "top_virtual_seq");
    super.new(name);
  endfunction

  virtual task body();
    apb_write_seq      apb_seq = apb_write_seq::type_id::create("apb_seq");
    axi_read_seq       axi_seq = axi_read_seq::type_id::create("axi_seq");

    fork
      apb_seq.start(apb_sqr);
      axi_seq.start(axi_sqr);
    join
  endtask
endclass
```

---

## 27. `uvm_agent`, `uvm_env`, and `uvm_test`

### `uvm_agent`

An agent encapsulates the driver, sequencer, and monitor for a single interface protocol. It provides `get_is_active()` to determine whether it should instantiate active components (driver + sequencer) or operate passively (monitor only).

```systemverilog
class apb_agent extends uvm_agent;
  `uvm_component_utils(apb_agent)

  apb_driver    drv;
  apb_sequencer sqr;
  apb_monitor   mon;
  apb_coverage  cov;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    mon = apb_monitor::type_id::create("mon", this);
    cov = apb_coverage::type_id::create("cov", this);
    if (get_is_active() == UVM_ACTIVE) begin
      drv = apb_driver::type_id::create("drv", this);
      sqr = apb_sequencer::type_id::create("sqr", this);
    end
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    mon.ap.connect(cov.analysis_export);
    if (get_is_active() == UVM_ACTIVE)
      drv.seq_item_port.connect(sqr.seq_item_export);
  endfunction
endclass
```

### `uvm_env`

An environment groups agents, scoreboards, and other sub-environments. It represents a **reusable verification context**.

```systemverilog
class apb_env extends uvm_env;
  `uvm_component_utils(apb_env)

  apb_agent      agent;
  apb_scoreboard scb;
  apb_ref_model  ref_model;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    agent     = apb_agent::type_id::create("agent", this);
    scb       = apb_scoreboard::type_id::create("scb", this);
    ref_model = apb_ref_model::type_id::create("ref_model", this);
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    agent.mon.ap.connect(ref_model.analysis_export);
    agent.mon.ap.connect(scb.actual_fifo.analysis_export);
    ref_model.ap.connect(scb.expected_fifo.analysis_export);
  endfunction
endclass
```

### `uvm_test`

The test is the top of the UVM component hierarchy. It configures the environment, runs sequences, and handles objections.

```systemverilog
class apb_base_test extends uvm_test;
  `uvm_component_utils(apb_base_test)

  apb_env env;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = apb_env::type_id::create("env", this);
    uvm_config_db #(uvm_active_passive_enum)::set(
      this, "env.agent", "is_active", UVM_ACTIVE
    );
  endfunction

  virtual function void end_of_elaboration_phase(uvm_phase phase);
    uvm_top.print_topology();
  endfunction
endclass

class apb_write_test extends apb_base_test;
  `uvm_component_utils(apb_write_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual task run_phase(uvm_phase phase);
    apb_write_seq seq = apb_write_seq::type_id::create("seq");

    phase.raise_objection(this);
    repeat (100) begin
      void'(seq.randomize());
      seq.start(env.agent.sqr);
    end
    phase.drop_objection(this);
  endtask
endclass
```

---

## 28. `uvm_scoreboard` and Comparators

### Custom Scoreboard

```systemverilog
class apb_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(apb_scoreboard)

  uvm_tlm_analysis_fifo #(APB_Transaction) expected_fifo;
  uvm_tlm_analysis_fifo #(APB_Transaction) actual_fifo;

  int unsigned match_count;
  int unsigned mismatch_count;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    expected_fifo = new("expected_fifo", this);
    actual_fifo   = new("actual_fifo", this);
  endfunction

  virtual task run_phase(uvm_phase phase);
    APB_Transaction expected_txn, actual_txn;

    forever begin
      expected_fifo.get(expected_txn);
      actual_fifo.get(actual_txn);

      if (expected_txn.compare(actual_txn)) begin
        match_count++;
        `uvm_info("SCB", $sformatf("MATCH #%0d: %s",
                  match_count, actual_txn.convert2string()), UVM_HIGH)
      end else begin
        mismatch_count++;
        `uvm_error("SCB", $sformatf(
          "MISMATCH #%0d:\n  Expected: %s\n  Actual:   %s",
          mismatch_count,
          expected_txn.convert2string(),
          actual_txn.convert2string()))
      end
    end
  endtask

  virtual function void report_phase(uvm_phase phase);
    `uvm_info("SCB", $sformatf(
      "\n========== Scoreboard Summary ==========\n  Matches:    %0d\n  Mismatches: %0d\n========================================",
      match_count, mismatch_count), UVM_LOW)

    if (mismatch_count > 0)
      `uvm_error("SCB", "TEST FAILED — mismatches detected")
    else
      `uvm_info("SCB", "TEST PASSED", UVM_LOW)
  endfunction
endclass
```

### Built-in Comparator

UVM provides `uvm_in_order_comparator #(T)` for simpler use cases:

```systemverilog
uvm_in_order_comparator #(APB_Transaction) comparator;

// Build
comparator = uvm_in_order_comparator #(APB_Transaction)::type_id::create("comparator", this);

// Connect
ref_model.ap.connect(comparator.before_export);
monitor.ap.connect(comparator.after_export);
```

---

## 29. UVM Reporting — `uvm_report_object`

The UVM reporting system provides severity-based messaging with hierarchical control.

### Severity Levels

| Macro | Severity | Default Action |
|-------|----------|---------------|
| `` `uvm_info(ID, MSG, VERBOSITY) `` | `UVM_INFO` | Display if verbosity allows |
| `` `uvm_warning(ID, MSG) `` | `UVM_WARNING` | Always display |
| `` `uvm_error(ID, MSG) `` | `UVM_ERROR` | Display + increment error count |
| `` `uvm_fatal(ID, MSG) `` | `UVM_FATAL` | Display + abort simulation |

### Verbosity Levels

```
UVM_NONE   = 0    — Always shown
UVM_LOW    = 100  — Important messages
UVM_MEDIUM = 200  — Standard information
UVM_HIGH   = 300  — Detailed debug
UVM_FULL   = 400  — Very detailed
UVM_DEBUG  = 500  — Maximum detail
```

### Controlling Reporting

```systemverilog
// Set verbosity from command line
// +UVM_VERBOSITY=UVM_HIGH

// Set verbosity programmatically
set_report_verbosity_level(UVM_HIGH);

// Set verbosity for a specific component and its children
env.agent.mon.set_report_verbosity_level(UVM_DEBUG);

// Override severity for a specific message ID
set_report_severity_id_override(UVM_WARNING, "LATE_RSP", UVM_ERROR);

// Set action for a specific severity
set_report_severity_action(UVM_ERROR, UVM_DISPLAY | UVM_LOG | UVM_COUNT);

// Set maximum error count before abort
set_report_max_quit_count(10);

// Redirect reports to a file
UVM_FILE log_file;
log_file = $fopen("simulation.log", "w");
set_report_default_file(log_file);
set_report_severity_action(UVM_INFO, UVM_DISPLAY | UVM_LOG);
```

### Internal Reporting Flow

```
  `uvm_info("TAG", "message", UVM_MEDIUM)
       │
       ▼
  uvm_report_info(...)         ← called on the component
       │
       ▼
  uvm_report_handler           ← checks severity, verbosity, actions
       │
       ├─ Verbosity check: is message verbosity <= component verbosity?
       ├─ ID filter: any ID-specific overrides?
       ├─ Severity override: any severity remapping?
       │
       ▼
  uvm_report_server            ← formats and dispatches
       │
       ├─ UVM_DISPLAY → $display
       ├─ UVM_LOG     → $fwrite to file
       ├─ UVM_COUNT   → increment quit count
       ├─ UVM_EXIT    → $finish
       └─ UVM_CALL_HOOK → report_hook()
```

---

## 30. UVM Register Abstraction Layer (RAL)

The RAL provides a structured model of DUT registers, enabling front-door and back-door access with automatic prediction.

### Class Hierarchy

```
uvm_reg_block
├── uvm_reg           (individual register)
│   └── uvm_reg_field (bit fields within a register)
├── uvm_reg_map       (address map)
└── uvm_mem           (memory)
```

### Building a Register Model

```systemverilog
// Step 1: Define register fields → registers → blocks

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

    //          parent, size, lsb, access,  volatile, reset, has_reset, rand
    enable.configure  (this,  1,   0, "RW",  0, 1'b0,  1, 1, 0);
    mode.configure    (this,  2,   1, "RW",  0, 2'b00, 1, 1, 0);
    irq_mask.configure(this,  8,   8, "RW",  0, 8'h00, 1, 1, 0);
  endfunction
endclass

class status_reg extends uvm_reg;
  `uvm_object_utils(status_reg)

  rand uvm_reg_field busy;
  rand uvm_reg_field error;
  rand uvm_reg_field irq_status;

  function new(string name = "status_reg");
    super.new(name, 32, UVM_NO_COVERAGE);
  endfunction

  virtual function void build();
    busy       = uvm_reg_field::type_id::create("busy");
    error      = uvm_reg_field::type_id::create("error");
    irq_status = uvm_reg_field::type_id::create("irq_status");

    busy.configure      (this, 1, 0, "RO", 1, 1'b0, 1, 0, 0);
    error.configure     (this, 1, 1, "RO", 1, 1'b0, 1, 0, 0);
    irq_status.configure(this, 8, 8, "W1C", 1, 8'h00, 1, 0, 0);
  endfunction
endclass

class my_reg_block extends uvm_reg_block;
  `uvm_object_utils(my_reg_block)

  rand ctrl_reg   ctrl;
  rand status_reg status;
  uvm_reg_map     default_map;

  function new(string name = "my_reg_block");
    super.new(name, UVM_NO_COVERAGE);
  endfunction

  virtual function void build();
    ctrl   = ctrl_reg::type_id::create("ctrl");
    status = status_reg::type_id::create("status");

    ctrl.configure(this, null, "");
    status.configure(this, null, "");

    ctrl.build();
    status.build();

    default_map = create_map("default_map", 'h0, 4, UVM_LITTLE_ENDIAN);
    default_map.add_reg(ctrl,   'h00, "RW");
    default_map.add_reg(status, 'h04, "RO");

    lock_model();
  endfunction
endclass
```

### Using the Register Model in Tests

```systemverilog
// Front-door access (goes through the bus agent)
virtual task run_phase(uvm_phase phase);
  uvm_status_e status;

  phase.raise_objection(this);

  // Write to ctrl register
  env.reg_block.ctrl.write(status, 32'h0000_0305);
  `uvm_info("TEST", $sformatf("Write status: %s", status.name()), UVM_LOW)

  // Read status register
  env.reg_block.status.read(status, rdata);
  `uvm_info("TEST", $sformatf("Status = 0x%08h", rdata), UVM_LOW)

  // Field-level access
  env.reg_block.ctrl.enable.set(1);
  env.reg_block.ctrl.mode.set(2'b10);
  env.reg_block.ctrl.update(status);    // writes the desired value

  // Mirror (read from DUT and update model)
  env.reg_block.status.mirror(status, UVM_CHECK);

  phase.drop_objection(this);
endtask
```

### RAL Key Methods

| Method | Description |
|--------|-------------|
| `write(status, data)` | Front-door write to DUT register |
| `read(status, data)` | Front-door read from DUT register |
| `set(value)` | Set desired value in model (no DUT access) |
| `get()` | Get desired value from model |
| `update(status)` | Write desired value to DUT if it differs from mirrored |
| `mirror(status, check)` | Read DUT and update model; optionally check against desired |
| `predict(value)` | Update model prediction without DUT access |
| `get_mirrored_value()` | Return last known DUT value |
| `reset()` | Reset model to reset values |
| `lock_model()` | Lock the model after building (required) |

---

## 31. Field Macros vs. Do-Methods

### Field Macros (Quick but Limited)

The `` `uvm_field_* `` macros automatically implement `copy`, `compare`, `print`, `pack`, and `unpack`:

```systemverilog
class simple_txn extends uvm_sequence_item;
  `uvm_object_utils_begin(simple_txn)
    `uvm_field_int(addr,   UVM_ALL_ON | UVM_HEX)
    `uvm_field_int(data,   UVM_ALL_ON | UVM_HEX)
    `uvm_field_int(write,  UVM_ALL_ON | UVM_BIN)
    `uvm_field_string(tag, UVM_ALL_ON)
    `uvm_field_enum(op_e, op, UVM_ALL_ON)
    `uvm_field_queue_int(payload, UVM_ALL_ON | UVM_HEX)
  `uvm_object_utils_end

  rand bit [31:0] addr;
  rand bit [31:0] data;
  rand bit        write;
  string          tag;
  rand op_e       op;
  rand bit [7:0]  payload[$];

  function new(string name = "simple_txn");
    super.new(name);
  endfunction
endclass
```

### Do-Methods (Recommended for Production)

The do-methods are more verbose but offer:
- Full control over comparison, printing, and packing
- Better simulation performance (no macro overhead)
- Easier debugging

See [Section 18](#18-uvm_object--core-data-methods) for a complete do-methods example.

### Comparison

| Aspect | Field Macros | Do-Methods |
|--------|-------------|------------|
| Lines of code | Fewer | More |
| Simulation speed | Slower (macro overhead) | Faster |
| Debuggability | Harder (macro expansion) | Easier |
| Flexibility | Limited | Full control |
| Industry preference | Prototyping | Production |

---

# Part III — Putting It All Together

## 32. Complete UVM Testbench Walk-through

Below is a complete, minimal UVM testbench for an APB slave. The numbered comments show the execution order.

### Top-level Module

```systemverilog
module tb_top;
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  import apb_pkg::*;

  logic pclk, preset_n;

  // Clock generation
  initial begin
    pclk = 0;
    forever #5 pclk = ~pclk;
  end

  // Reset
  initial begin
    preset_n = 0;
    #100;
    preset_n = 1;
  end

  // Interface instance
  apb_if apb_vif(.pclk(pclk), .preset_n(preset_n));

  // DUT
  apb_slave dut (
    .pclk    (pclk),
    .preset_n(preset_n),
    .psel    (apb_vif.psel),
    .penable (apb_vif.penable),
    .paddr   (apb_vif.paddr),
    .pwrite  (apb_vif.pwrite),
    .pwdata  (apb_vif.pwdata),
    .prdata  (apb_vif.prdata),
    .pready  (apb_vif.pready),
    .pslverr (apb_vif.pslverr)
  );

  // UVM test launch
  initial begin
    // (1) Pass virtual interface into config_db
    uvm_config_db #(virtual apb_if)::set(null, "uvm_test_top.*", "vif", apb_vif);

    // (2) Start the test — UVM takes over from here
    run_test("apb_write_test");
  end
endmodule
```

### Execution Flow

```
 ┌───────────────────────────────────────────────────────────┐
 │  run_test("apb_write_test")                               │
 │      │                                                     │
 │      ▼                                                     │
 │  Factory creates apb_write_test (extends apb_base_test)   │
 │      │                                                     │
 │  ════╪══════════════ BUILD PHASE (top-down) ══════════════ │
 │      ▼                                                     │
 │  apb_write_test.build_phase()                              │
 │      └─ creates apb_env                                    │
 │          └─ apb_env.build_phase()                          │
 │              ├─ creates apb_agent                          │
 │              │   └─ apb_agent.build_phase()                │
 │              │       ├─ creates apb_driver                 │
 │              │       ├─ creates apb_sequencer              │
 │              │       └─ creates apb_monitor                │
 │              └─ creates apb_scoreboard                     │
 │                                                            │
 │  ════════════ CONNECT PHASE (bottom-up) ═══════════════    │
 │                                                            │
 │  apb_agent.connect_phase()                                 │
 │      └─ drv.seq_item_port.connect(sqr.seq_item_export)    │
 │  apb_env.connect_phase()                                   │
 │      └─ agent.mon.ap.connect(scb.ap_imp)                  │
 │                                                            │
 │  ══════════════ RUN PHASE (parallel) ═══════════════════   │
 │                                                            │
 │  apb_write_test.run_phase()                                │
 │      ├─ raise_objection                                    │
 │      ├─ seq.start(env.agent.sqr) ─── sequence body() ─┐   │
 │      │                            start_item(txn) ──┐  │   │
 │      │                            finish_item(txn) ─┘  │   │
 │      │                            ← driver drives DUT  │   │
 │      │                            ← monitor collects   │   │
 │      │                            ← scoreboard checks  │   │
 │      └─ drop_objection                                     │
 │                                                            │
 │  ═══════════ CLEANUP PHASES (bottom-up) ════════════════   │
 │                                                            │
 │  extract_phase → check_phase → report_phase → final_phase │
 └───────────────────────────────────────────────────────────┘
```

---

## 33. Best Practices and Common Pitfalls

### Best Practices

1. **Always use the factory** — `type_id::create()`, never `new()` for UVM classes
2. **Implement do-methods** — Prefer manual `do_copy`, `do_compare`, `do_print` over field macros in production
3. **Use `convert2string()`** — For transaction printing in `uvm_info` messages
4. **Make methods virtual** — Especially in base classes, to enable polymorphic overrides
5. **Call `super.*_phase()`** — Always call the parent's phase method at the start of your override
6. **Use `uvm_config_db`** — For passing configuration objects and virtual interfaces, not for passing data during simulation
7. **Raise/drop objections in tests** — Not in drivers or monitors
8. **Use analysis ports** — For passive, broadcast communication; never pass data through the component hierarchy manually
9. **Separate concerns** — Agent = protocol; Environment = connectivity; Test = stimulus + configuration
10. **Use configuration objects** — Bundle agent/env config into a class and pass it via `uvm_config_db`

### Common Pitfalls

| Pitfall | Problem | Solution |
|---------|---------|----------|
| Using `new()` instead of `create()` | Factory overrides won't work | Always use `type_id::create()` |
| Forgetting `super.build_phase()` | Parent build logic skipped | Always call `super.build_phase(phase)` first |
| Wrong constructor signature | Component: `(name, parent)`, Object: `(name)` | Follow the convention strictly |
| Missing `virtual` on methods | Polymorphism broken | Declare `virtual` on base class methods |
| Forgetting `\`uvm_component_utils` / `\`uvm_object_utils` | Factory registration missing | Always add the registration macro |
| Missing objection raise | `run_phase` ends immediately | Raise objection before starting sequences |
| Driving from monitor | Violates passive observation | Only drivers should drive signals |
| Wrong `$cast` direction | Run-time errors | Cast from base handle to derived type |
| Connecting ports wrong | `connect()` goes from port → export/imp | Port.connect(export), never reverse |
| Forgetting `lock_model()` in RAL | Register model unusable | Call after building all registers and maps |

### Configuration Object Pattern

```systemverilog
class apb_agent_config extends uvm_object;
  `uvm_object_utils(apb_agent_config)

  virtual apb_if           vif;
  uvm_active_passive_enum  is_active = UVM_ACTIVE;
  bit                      has_coverage = 1;
  bit                      has_scoreboard = 1;
  int unsigned             max_retry = 3;

  function new(string name = "apb_agent_config");
    super.new(name);
  endfunction
endclass

// In test
class my_test extends uvm_test;
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    apb_agent_config cfg = apb_agent_config::type_id::create("cfg");
    cfg.vif = tb_top.apb_vif;
    cfg.is_active = UVM_ACTIVE;
    uvm_config_db #(apb_agent_config)::set(this, "env.agent*", "cfg", cfg);
  endfunction
endclass

// In agent
class apb_agent extends uvm_agent;
  apb_agent_config cfg;

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(apb_agent_config)::get(this, "", "cfg", cfg))
      `uvm_fatal("NOCFG", "Agent config not found")
    // Use cfg.is_active instead of get_is_active()
    if (cfg.is_active == UVM_ACTIVE) begin
      drv = apb_driver::type_id::create("drv", this);
      sqr = apb_sequencer::type_id::create("sqr", this);
    end
  endfunction
endclass
```

---

## Quick Reference Card

### Class Registration Macros

| Class Type | Macro | Constructor |
|------------|-------|-------------|
| `uvm_object` subclass | `` `uvm_object_utils(T) `` | `new(string name)` |
| `uvm_component` subclass | `` `uvm_component_utils(T) `` | `new(string name, uvm_component parent)` |
| Parameterized object | `` `uvm_object_param_utils(T) `` | `new(string name)` |
| Parameterized component | `` `uvm_component_param_utils(T) `` | `new(string name, uvm_component parent)` |

### Essential UVM Macros

```systemverilog
`uvm_info   ("TAG", "message", UVM_MEDIUM)   // informational
`uvm_warning("TAG", "message")               // warning
`uvm_error  ("TAG", "message")               // error (counted)
`uvm_fatal  ("TAG", "message")               // fatal (aborts)
`uvm_do(item)                                // create + randomize + send
`uvm_do_with(item, {constraints})            // with inline constraints
`uvm_create(item)                            // factory-create without sending
`uvm_send(item)                              // send previously created item
```

### Common Command-Line Arguments

```bash
# Run a specific test
+UVM_TESTNAME=apb_write_test

# Set verbosity
+UVM_VERBOSITY=UVM_HIGH

# Set timeout
+UVM_TIMEOUT=1000000

# Enable factory debug
+UVM_DUMP_CMDLN_ARGS

# Set max quit count
+UVM_MAX_QUIT_COUNT=5
```

---

*End of tutorial.*
