# SystemVerilog Classes & UVM — A Comprehensive Tutorial

A deep-dive guide covering SystemVerilog object-oriented programming and the Universal Verification Methodology (UVM), with practical, annotated examples for verification engineers.

---

## Table of Contents

| Part | Section | Topic |
|------|---------|-------|
| **I** | 1 | [Why Classes in Hardware Verification?](#1-why-classes-in-hardware-verification) |
| **I** | 2 | [Class Fundamentals](#2-class-fundamentals) |
| **I** | 3 | [The Constructor — `new()`](#3-the-constructor--new) |
| **I** | 4 | [Properties and Methods](#4-properties-and-methods) |
| **I** | 5 | [Access Control — `local` and `protected`](#5-access-control--local-and-protected) |
| **I** | 6 | [Inheritance](#6-inheritance) |
| **I** | 7 | [Polymorphism and Virtual Methods](#7-polymorphism-and-virtual-methods) |
| **I** | 8 | [Abstract Classes and Pure Virtual Methods](#8-abstract-classes-and-pure-virtual-methods) |
| **I** | 9 | [Parameterized (Generic) Classes](#9-parameterized-generic-classes) |
| **I** | 10 | [Static Members](#10-static-members) |
| **I** | 11 | [Copying Objects — Shallow vs Deep](#11-copying-objects--shallow-vs-deep) |
| **I** | 12 | [Randomization and Constraints](#12-randomization-and-constraints) |
| **I** | 13 | [Typedef, Forward Declarations, and Scope Resolution](#13-typedef-forward-declarations-and-scope-resolution) |
| **I** | 14 | [Class Casting — `$cast`](#14-class-casting--cast) |
| **II** | 15 | [Introduction to UVM](#15-introduction-to-uvm) |
| **II** | 16 | [UVM Class Hierarchy Overview](#16-uvm-class-hierarchy-overview) |
| **II** | 17 | [`uvm_object` — The Root of Everything](#17-uvm_object--the-root-of-everything) |
| **II** | 18 | [`uvm_component` — Structural Backbone](#18-uvm_component--structural-backbone) |
| **II** | 19 | [UVM Phasing Mechanism](#19-uvm-phasing-mechanism) |
| **II** | 20 | [`uvm_transaction` and `uvm_sequence_item`](#20-uvm_transaction-and-uvm_sequence_item) |
| **II** | 21 | [`uvm_sequence` — Stimulus Generation](#21-uvm_sequence--stimulus-generation) |
| **II** | 22 | [`uvm_driver` — Driving the DUT](#22-uvm_driver--driving-the-dut) |
| **II** | 23 | [`uvm_sequencer` — Arbitration](#23-uvm_sequencer--arbitration) |
| **II** | 24 | [`uvm_monitor` — Passive Observation](#24-uvm_monitor--passive-observation) |
| **II** | 25 | [`uvm_agent` — Grouping Driver, Sequencer, Monitor](#25-uvm_agent--grouping-driver-sequencer-monitor) |
| **II** | 26 | [`uvm_scoreboard` — Checking Results](#26-uvm_scoreboard--checking-results) |
| **II** | 27 | [`uvm_env` — Top-Level Environment](#27-uvm_env--top-level-environment) |
| **II** | 28 | [`uvm_test` — Test Entry Point](#28-uvm_test--test-entry-point) |
| **II** | 29 | [The UVM Factory](#29-the-uvm-factory) |
| **II** | 30 | [Configuration Database — `uvm_config_db`](#30-configuration-database--uvm_config_db) |
| **II** | 31 | [TLM Ports and Communication](#31-tlm-ports-and-communication) |
| **II** | 32 | [UVM Reporting and Messaging](#32-uvm-reporting-and-messaging) |
| **II** | 33 | [Field Automation Macros — `uvm_field_*`](#33-field-automation-macros--uvm_field_) |
| **II** | 34 | [Register Abstraction Layer (RAL) Overview](#34-register-abstraction-layer-ral-overview) |
| **III** | 35 | [Complete UVM Testbench Walkthrough](#35-complete-uvm-testbench-walkthrough) |

---

# Part I — SystemVerilog Classes

---

## 1. Why Classes in Hardware Verification?

Traditional Verilog relies on modules, tasks, and functions. These constructs work well for RTL design but fall short in verification:

- **No data encapsulation** — every signal is globally visible inside a module.
- **No inheritance** — code reuse requires `include` or copy-paste.
- **No polymorphism** — you cannot swap behaviour at runtime.
- **No dynamic memory** — modules are instantiated at elaboration time and cannot be created or destroyed during simulation.

SystemVerilog classes solve all of these problems. They bring object-oriented programming (OOP) to the verification world, enabling reusable, configurable, and layered testbenches. UVM is built entirely on top of SystemVerilog classes.

**Key OOP concepts used in verification:**

| Concept | Verification Benefit |
|---------|---------------------|
| Encapsulation | Hide internal state of transactions, scoreboards |
| Inheritance | Extend a base transaction to create protocol variants |
| Polymorphism | Swap drivers/sequences via the factory without changing structure |
| Dynamic allocation | Create transactions on the fly during simulation |
| Randomization | Constrained-random stimulus generation built into class objects |

---

## 2. Class Fundamentals

A SystemVerilog class is a user-defined type that bundles data (properties) and behaviour (methods).

```systemverilog
class Packet;
    // Properties (data members)
    bit [7:0]  src_addr;
    bit [7:0]  dst_addr;
    bit [31:0] payload;
    bit [15:0] crc;

    // Method
    function void compute_crc();
        crc = src_addr ^ dst_addr ^ payload[15:0] ^ payload[31:16];
    endfunction

    function void display();
        $display("Packet: src=%0h dst=%0h payload=%0h crc=%0h",
                 src_addr, dst_addr, payload, crc);
    endfunction
endclass
```

**Declaring and using a class object:**

```systemverilog
module tb;
    initial begin
        Packet pkt;          // Declare a handle (null by default)
        pkt = new();         // Allocate the object
        pkt.src_addr = 8'hA5;
        pkt.dst_addr = 8'h3C;
        pkt.payload  = 32'hDEAD_BEEF;
        pkt.compute_crc();
        pkt.display();
    end
endmodule
```

**Key points:**

- `Packet pkt;` declares a *handle* (pointer), not the object itself. Its initial value is `null`.
- `pkt = new();` dynamically allocates the object on the heap and returns a handle.
- Objects are garbage-collected when no handles reference them.
- Unlike modules, classes can be created and destroyed at runtime.

---

## 3. The Constructor — `new()`

The constructor initializes a newly allocated object. If you do not define one, SystemVerilog provides a default that sets all properties to their default values (0 for integral types, `null` for handles).

```systemverilog
class Packet;
    bit [7:0]  src_addr;
    bit [7:0]  dst_addr;
    bit [31:0] payload;

    // Explicit constructor
    function new(bit [7:0] src = 0, bit [7:0] dst = 0);
        this.src_addr = src;
        this.dst_addr = dst;
        this.payload  = 0;
    endfunction
endclass
```

Usage:

```systemverilog
Packet p1 = new();             // src=0, dst=0
Packet p2 = new(8'hAA, 8'hBB); // src=AA, dst=BB
```

**The `this` keyword** refers to the current object instance, useful when parameter names shadow property names:

```systemverilog
function new(bit [7:0] src_addr, bit [7:0] dst_addr);
    this.src_addr = src_addr;   // 'this.' disambiguates
    this.dst_addr = dst_addr;
endfunction
```

---

## 4. Properties and Methods

### 4.1 Properties

Properties are data members. They can be any SystemVerilog type:

```systemverilog
class Transaction;
    rand  bit [31:0] address;     // random variable
    randc bit [7:0]  data;        // cyclic random
    int              delay;       // plain integer
    string           name;        // string type
    Packet           pkt_handle;  // handle to another class
    bit [7:0]        mem_array[]; // dynamic array
endclass
```

### 4.2 Methods — Functions and Tasks

- **Functions** execute in zero simulation time and return a value (or `void`).
- **Tasks** can consume simulation time (contain `#delays`, `@events`, `wait` statements).

```systemverilog
class BusDriver;
    virtual interface bus_if vif;

    // Function — zero time
    function bit check_valid(bit [31:0] addr);
        return (addr inside {[32'h0000:32'hFFFF]});
    endfunction

    // Task — can consume simulation time
    task drive(input Transaction tr);
        @(posedge vif.clk);
        vif.addr  <= tr.address;
        vif.data  <= tr.data;
        vif.valid <= 1'b1;
        @(posedge vif.clk);
        vif.valid <= 1'b0;
    endtask
endclass
```

### 4.3 Arguments — `ref`, `input`, `output`, `inout`

```systemverilog
function void swap(ref int a, ref int b);
    int tmp = a;
    a = b;
    b = tmp;
endfunction
```

- `input` (default) — value is copied in.
- `output` — value is copied out after the function/task returns.
- `inout` — copied in and copied out.
- `ref` — passed by reference (most efficient for large objects).

---

## 5. Access Control — `local` and `protected`

SystemVerilog provides three visibility levels:

| Keyword | Accessible From |
|---------|----------------|
| *(default)* | Anywhere (public) |
| `protected` | The class itself and any subclass |
| `local` | Only the class itself |

```systemverilog
class Account;
    local    int balance;       // only Account methods
    protected int account_id;   // Account + subclasses

    function new(int id, int initial_balance);
        account_id = id;
        balance    = initial_balance;
    endfunction

    function int get_balance();
        return balance;
    endfunction

    function void deposit(int amount);
        if (amount > 0) balance += amount;
    endfunction
endclass

class SavingsAccount extends Account;
    protected int interest_rate;

    function void apply_interest();
        // Can access 'account_id' (protected) — OK
        // Cannot access 'balance' (local to Account) — compile error
        // Must use get_balance() instead
        int current = get_balance();
        deposit(current * interest_rate / 100);
    endfunction
endclass
```

---

## 6. Inheritance

Inheritance lets a derived (child) class reuse and extend a base (parent) class.

```systemverilog
class BaseTransaction;
    bit [31:0] address;
    bit [31:0] data;
    bit        write;

    function void display();
        $display("[BaseTxn] addr=%0h data=%0h wr=%0b", address, data, write);
    endfunction
endclass

class BurstTransaction extends BaseTransaction;
    int burst_length;
    bit [2:0] burst_type;  // FIXED, INCR, WRAP

    function void display();
        super.display();  // call parent method
        $display("         burst_len=%0d burst_type=%0b", burst_length, burst_type);
    endfunction
endclass
```

**The `super` keyword** calls the parent class's method:

```systemverilog
class Child extends Parent;
    function new(string name);
        super.new(name);   // call Parent's constructor
    endfunction
endclass
```

**Key rules:**

1. A child inherits all non-`local` properties and methods.
2. Constructors are **not** inherited; each class must define its own if needed.
3. If the parent's constructor takes arguments, the child **must** call `super.new(...)` explicitly.
4. SystemVerilog supports single inheritance only (one parent per class).

---

## 7. Polymorphism and Virtual Methods

Polymorphism allows a parent handle to invoke a child method — but only when the method is declared `virtual`.

### Without `virtual` (static dispatch — **wrong** behaviour):

```systemverilog
class Animal;
    function void speak();
        $display("...");
    endfunction
endclass

class Dog extends Animal;
    function void speak();
        $display("Woof!");
    endfunction
endclass

Animal a;
Dog    d = new();
a = d;          // parent handle pointing to child object
a.speak();      // prints "..." — calls Animal::speak() (static binding)
```

### With `virtual` (dynamic dispatch — **correct** behaviour):

```systemverilog
class Animal;
    virtual function void speak();
        $display("...");
    endfunction
endclass

class Dog extends Animal;
    virtual function void speak();
        $display("Woof!");
    endfunction
endclass

Animal a;
Dog    d = new();
a = d;
a.speak();      // prints "Woof!" — calls Dog::speak() (dynamic binding)
```

**Why this matters in UVM:** The factory replaces a base class with a derived class at runtime. If the methods are not `virtual`, the substituted object's methods will never be called. UVM macros automatically register classes for factory use, and the framework relies on virtual methods throughout.

---

## 8. Abstract Classes and Pure Virtual Methods

An abstract class cannot be instantiated directly. It serves as a contract that subclasses must fulfil.

```systemverilog
virtual class Shape;
    pure virtual function real area();
    pure virtual function void display();
endclass

class Circle extends Shape;
    real radius;

    function new(real r);
        radius = r;
    endfunction

    virtual function real area();
        return 3.14159 * radius * radius;
    endfunction

    virtual function void display();
        $display("Circle: radius=%.2f area=%.2f", radius, area());
    endfunction
endclass

class Rectangle extends Shape;
    real width, height;

    function new(real w, real h);
        width = w;
        height = h;
    endfunction

    virtual function real area();
        return width * height;
    endfunction

    virtual function void display();
        $display("Rectangle: %.2f x %.2f area=%.2f", width, height, area());
    endfunction
endclass
```

Usage:

```systemverilog
Shape shapes[$];
shapes.push_back(new Circle(5.0));
shapes.push_back(new Rectangle(3.0, 4.0));

foreach (shapes[i])
    shapes[i].display();   // polymorphic call
```

**Rule:** Any class with at least one `pure virtual` method is implicitly abstract (must be declared with `virtual class`).

---

## 9. Parameterized (Generic) Classes

Parameterized classes are templates that can be customized at instantiation.

```systemverilog
class Stack #(type T = int, int DEPTH = 16);
    T data[$];

    function void push(T item);
        if (data.size() < DEPTH)
            data.push_back(item);
        else
            $error("Stack overflow! Max depth = %0d", DEPTH);
    endfunction

    function T pop();
        if (data.size() > 0)
            return data.pop_back();
        else begin
            $error("Stack underflow!");
            pop = T'(0);
        end
    endfunction

    function int size();
        return data.size();
    endfunction

    function bit is_empty();
        return (data.size() == 0);
    endfunction
endclass
```

Usage:

```systemverilog
Stack #(bit [31:0], 64) addr_stack = new();  // 32-bit stack, depth 64
Stack #(string, 8)      name_stack = new();  // string stack, depth 8
Stack                    int_stack  = new();  // defaults: int, depth 16

addr_stack.push(32'hDEAD_BEEF);
name_stack.push("hello");
```

UVM uses parameterized classes extensively — `uvm_driver #(REQ, RSP)`, `uvm_sequencer #(REQ, RSP)`, `uvm_tlm_fifo #(T)`, etc.

---

## 10. Static Members

Static properties and methods belong to the class itself, not to any instance.

```systemverilog
class Transaction;
    static int count = 0;       // shared across all instances
    int        id;

    function new();
        count++;
        id = count;
    endfunction

    static function int get_count();
        return count;
    endfunction
endclass
```

```systemverilog
Transaction t1 = new();    // count=1, t1.id=1
Transaction t2 = new();    // count=2, t2.id=2
$display("Total: %0d", Transaction::get_count());  // prints 2
```

**Rules:**
- Static methods can only access static properties (no `this`).
- Access static members via `ClassName::member` or through any instance.
- Useful for singleton patterns, counters, and registries (UVM's factory is a singleton).

---

## 11. Copying Objects — Shallow vs Deep

### Shallow copy (default `new` copy):

```systemverilog
class Inner;
    int value;
endclass

class Outer;
    int    x;
    Inner  inner_obj;

    function new();
        inner_obj = new();
    endfunction
endclass

Outer a = new();
a.x = 10;
a.inner_obj.value = 42;

Outer b = new a;           // SHALLOW copy
b.x = 20;                  // b.x is independent copy
b.inner_obj.value = 99;    // CHANGES a.inner_obj.value too!
// Both a.inner_obj and b.inner_obj point to the SAME Inner object
```

### Deep copy (manual implementation):

```systemverilog
class Outer;
    int    x;
    Inner  inner_obj;

    function new();
        inner_obj = new();
    endfunction

    function Outer deep_copy();
        Outer cpy = new();
        cpy.x = this.x;
        cpy.inner_obj = new();
        cpy.inner_obj.value = this.inner_obj.value;
        return cpy;
    endfunction
endclass

Outer a = new();
a.x = 10;
a.inner_obj.value = 42;

Outer b = a.deep_copy();   // DEEP copy — fully independent
b.inner_obj.value = 99;    // a.inner_obj.value is still 42
```

UVM solves this systematically with `clone()`, `copy()`, and `do_copy()` virtual methods in `uvm_object`.

---

## 12. Randomization and Constraints

SystemVerilog's constrained-random verification (CRV) is a major reason for using classes.

### 12.1 `rand` and `randc`

```systemverilog
class EthPacket;
    rand  bit [47:0] dst_mac;
    rand  bit [47:0] src_mac;
    rand  bit [15:0] ethertype;
    rand  bit [7:0]  payload[];
    randc bit [2:0]  priority;     // cyclic — exhausts all values before repeating

    constraint payload_size_c {
        payload.size() inside {[46:1500]};  // valid Ethernet payload range
    }

    constraint ethertype_c {
        ethertype inside {16'h0800, 16'h0806, 16'h86DD};  // IPv4, ARP, IPv6
    }
endclass
```

### 12.2 Common Constraint Patterns

```systemverilog
class Transaction;
    rand bit [31:0] address;
    rand bit [31:0] data;
    rand bit [3:0]  burst_len;
    rand bit        write;

    // Range constraint
    constraint addr_range_c {
        address inside {[32'h0000_0000:32'h0000_FFFF]};
    }

    // Conditional (implication) constraint
    constraint write_implies_c {
        write -> (data != 0);   // if write, data must be non-zero
    }

    // Distribution constraint
    constraint write_dist_c {
        write dist {1 := 70, 0 := 30};  // 70% writes, 30% reads
    }

    // Ordering constraint
    constraint burst_c {
        burst_len inside {1, 2, 4, 8, 16};
        (burst_len > 1) -> (address % (burst_len * 4) == 0);  // alignment
    }

    // Soft constraint (can be overridden)
    constraint default_addr_c {
        soft address < 32'h0000_1000;
    }
endclass
```

### 12.3 Controlling Randomization

```systemverilog
Transaction tr = new();

// Basic randomization
if (!tr.randomize())
    $error("Randomization failed!");

// Inline constraints (add constraints at call site)
if (!tr.randomize() with {
    address == 32'h0000_0100;
    write   == 1;
})
    $error("Randomization failed!");

// Disable a constraint
tr.addr_range_c.constraint_mode(0);

// Disable randomization of a variable
tr.address.rand_mode(0);
tr.address = 32'hDEAD_BEEF;  // set manually
tr.randomize();                // randomizes everything except address
```

### 12.4 `pre_randomize()` and `post_randomize()`

These callbacks run automatically before and after `randomize()`:

```systemverilog
class Packet;
    rand bit [7:0] data[];
    bit  [15:0]    checksum;

    function void pre_randomize();
        $display("About to randomize packet");
    endfunction

    function void post_randomize();
        checksum = 0;
        foreach (data[i])
            checksum += data[i];
    endfunction
endclass
```

---

## 13. Typedef, Forward Declarations, and Scope Resolution

### 13.1 Forward declarations

When two classes reference each other, use a forward declaration:

```systemverilog
typedef class Node;    // forward declaration

class LinkedList;
    Node head;

    function void insert(int data);
        Node n = new(data, head);
        head = n;
    endfunction
endclass

class Node;
    int  data;
    Node next;

    function new(int d, Node n);
        data = d;
        next = n;
    endfunction
endclass
```

### 13.2 Scope Resolution Operator `::`

```systemverilog
class Outer;
    typedef enum {READ, WRITE} op_e;

    class Inner;
        function void show(Outer::op_e op);
            $display("Operation: %s", op.name());
        endfunction
    endclass
endclass

// External usage
Outer::op_e my_op = Outer::WRITE;
```

### 13.3 Extern Methods

Declare a method inside the class but define it outside:

```systemverilog
class BigClass;
    extern function void complex_operation(int a, int b);
endclass

function void BigClass::complex_operation(int a, int b);
    // full implementation here
    $display("result = %0d", a + b);
endfunction
```

---

## 14. Class Casting — `$cast`

When you need to convert a parent handle to a child handle, use `$cast`:

```systemverilog
class Animal;
    string name;
endclass

class Dog extends Animal;
    int tricks;
endclass

Animal a = new Dog();   // Upcast — implicit, always safe

Dog d;
// d = a;              // COMPILE ERROR — downcast not allowed implicitly

// Safe downcast with $cast:
if ($cast(d, a))
    $display("Cast succeeded! tricks=%0d", d.tricks);
else
    $display("Cast failed — 'a' does not point to a Dog");
```

**Two forms of `$cast`:**

| Form | Behaviour on Failure |
|------|---------------------|
| `$cast(dest, src)` as function | Returns 0 (no error) |
| `$cast(dest, src)` as task | Generates a runtime error |

In UVM, `$cast` is used frequently when pulling sequence items from queues or ports that are typed to the base class.

---

# Part II — UVM (Universal Verification Methodology)

---

## 15. Introduction to UVM

UVM is a standardized verification methodology (IEEE 1800.2) built entirely on SystemVerilog classes. It provides:

1. **A class library** — pre-built base classes for every testbench component.
2. **A phasing mechanism** — ordered startup, run, and shutdown.
3. **A factory** — object creation with runtime substitution.
4. **A configuration database** — hierarchical parameter passing.
5. **TLM communication** — loosely coupled component-to-component data flow.
6. **Reporting** — unified messaging with severity, verbosity, and actions.
7. **Sequences** — layered, reusable stimulus generation.

### The standard UVM testbench architecture:

```
┌────────────────────────────────────────────────────┐
│                     uvm_test                       │
│  ┌──────────────────────────────────────────────┐  │
│  │                  uvm_env                     │  │
│  │  ┌────────────────────┐  ┌────────────────┐  │  │
│  │  │     uvm_agent      │  │ uvm_scoreboard │  │  │
│  │  │  ┌──────────────┐  │  │                │  │  │
│  │  │  │ uvm_sequencer│  │  │   reference    │  │  │
│  │  │  └──────┬───────┘  │  │     model      │  │  │
│  │  │         │          │  │                │  │  │
│  │  │  ┌──────▼───────┐  │  └───────▲────────┘  │  │
│  │  │  │  uvm_driver  │  │          │            │  │
│  │  │  └──────┬───────┘  │   ┌──────┴────────┐   │  │
│  │  │         │          │   │  uvm_monitor   │   │  │
│  │  │  ┌──────▼───────┐  │   │  (analysis)    │   │  │
│  │  │  │  Interface   │  │   └───────▲────────┘   │  │
│  │  └──┼──────────────┼──┘           │            │  │
│  └─────┼──────────────┼─────────────┼────────────┘  │
└────────┼──────────────┼─────────────┼────────────────┘
         │              │             │
    ═════▼══════════════▼═════════════▼═════════════
                        DUT
    ════════════════════════════════════════════════
```

---

## 16. UVM Class Hierarchy Overview

All UVM classes trace back to `uvm_void`:

```
uvm_void
├── uvm_object
│   ├── uvm_transaction
│   │   └── uvm_sequence_item
│   │       └── your_transaction
│   ├── uvm_sequence
│   │   └── your_sequence
│   ├── uvm_reg_field
│   ├── uvm_reg
│   ├── uvm_reg_block
│   └── uvm_event
├── uvm_component
│   ├── uvm_driver
│   ├── uvm_monitor
│   ├── uvm_sequencer
│   ├── uvm_agent
│   ├── uvm_scoreboard
│   ├── uvm_env
│   └── uvm_test
└── uvm_port_base
    ├── uvm_analysis_port
    ├── uvm_tlm_fifo
    └── ...
```

**Two fundamental branches:**

| Branch | Purpose | Key Difference |
|--------|---------|----------------|
| `uvm_object` | Data objects — transactions, sequences, configurations | No hierarchy, no phases. Transient. |
| `uvm_component` | Structural elements — drivers, monitors, agents | Has parent-child hierarchy and phase callbacks. Persistent. |

---

## 17. `uvm_object` — The Root of Everything

`uvm_object` is the base for all UVM data classes. It provides the "common services" that every object needs.

### 17.1 Key Built-in Methods

| Method | Purpose | When to Override |
|--------|---------|-----------------|
| `new(string name)` | Constructor | Always — pass a name string |
| `copy(uvm_object rhs)` | Copy from another object | Override `do_copy()` instead |
| `clone()` | Create + copy | Relies on `create()` and `copy()` |
| `compare(uvm_object rhs)` | Deep equality comparison | Override `do_compare()` |
| `print()` | Print fields to console | Override `do_print()` |
| `sprint()` | Return string representation | Override `do_print()` |
| `pack() / unpack()` | Convert to/from bit stream | Override `do_pack() / do_unpack()` |
| `record()` | Record to a database (waveform) | Override `do_record()` |
| `create(string name)` | Factory-based object creation | Handled by factory macros |
| `get_name()` | Return the object name | Inherited |
| `get_type_name()` | Return the class type as string | Handled by factory macros |

### 17.2 The `do_*` Hook Pattern

UVM uses the **Template Method** design pattern. The public method (e.g., `copy()`) does common bookkeeping, then calls a `virtual` hook (`do_copy()`) that you override:

```systemverilog
// Inside uvm_object (simplified):
function void copy(uvm_object rhs);
    // --- common checks ---
    if (rhs == null) `uvm_fatal("COPY", "Null rhs")
    // --- call user hook ---
    do_copy(rhs);
endfunction

virtual function void do_copy(uvm_object rhs);
    // default: does nothing — you override this
endfunction
```

### 17.3 Implementing `do_copy`, `do_compare`, `do_print`

```systemverilog
class apb_transaction extends uvm_sequence_item;
    `uvm_object_utils(apb_transaction)

    rand bit [31:0] addr;
    rand bit [31:0] data;
    rand bit        write;

    function new(string name = "apb_transaction");
        super.new(name);
    endfunction

    // --- Deep Copy ---
    virtual function void do_copy(uvm_object rhs);
        apb_transaction rhs_;
        super.do_copy(rhs);
        $cast(rhs_, rhs);
        this.addr  = rhs_.addr;
        this.data  = rhs_.data;
        this.write = rhs_.write;
    endfunction

    // --- Deep Compare ---
    virtual function bit do_compare(uvm_object rhs, uvm_comparer comparer);
        apb_transaction rhs_;
        bit status;
        status = super.do_compare(rhs, comparer);
        $cast(rhs_, rhs);
        status &= (this.addr  == rhs_.addr);
        status &= (this.data  == rhs_.data);
        status &= (this.write == rhs_.write);
        return status;
    endfunction

    // --- Pretty Print ---
    virtual function void do_print(uvm_printer printer);
        super.do_print(printer);
        printer.print_field_int("addr",  addr,  32, UVM_HEX);
        printer.print_field_int("data",  data,  32, UVM_HEX);
        printer.print_field_int("write", write,  1, UVM_BIN);
    endfunction

    // --- Convert to String ---
    virtual function string convert2string();
        return $sformatf("APB %s addr=0x%08h data=0x%08h",
                         write ? "WR" : "RD", addr, data);
    endfunction
endclass
```

---

## 18. `uvm_component` — Structural Backbone

`uvm_component` extends `uvm_object` with:

1. **A hierarchical name** — parent-child tree matching the testbench structure.
2. **Phase callbacks** — `build_phase`, `connect_phase`, `run_phase`, etc.
3. **Configuration access** — interact with `uvm_config_db`.
4. **Factory registration** — automatic factory support via macros.

### 18.1 Key Additional Methods

| Method | Purpose |
|--------|---------|
| `new(string name, uvm_component parent)` | Constructor with parent reference |
| `build_phase(uvm_phase phase)` | Create sub-components, get config |
| `connect_phase(uvm_phase phase)` | Connect TLM ports |
| `run_phase(uvm_phase phase)` | Main simulation activity (task) |
| `report_phase(uvm_phase phase)` | Print final statistics |
| `get_parent()` | Return parent component |
| `get_full_name()` | Return hierarchical path (e.g., `uvm_test_top.env.agent.driver`) |
| `get_children(ref uvm_component children[$])` | Get child components |
| `lookup(string name)` | Find component by path |

### 18.2 Hierarchical Naming

```systemverilog
class my_driver extends uvm_driver #(apb_transaction);
    `uvm_component_utils(my_driver)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    // ... phases ...
endclass
```

When `my_driver` is created inside an agent named `"agt"` inside an env named `"env"`, its full hierarchical name is:

```
uvm_test_top.env.agt.drv
```

This naming mirrors RTL module hierarchy, making debug natural.

---

## 19. UVM Phasing Mechanism

UVM executes phases in a defined order. Each phase is a virtual method callback in `uvm_component`.

### 19.1 Phase Execution Order

```
                    ┌─────────────────────┐
                    │   build_phase       │  Top-down
                    └─────────┬───────────┘
                    ┌─────────▼───────────┐
                    │   connect_phase     │  Bottom-up
                    └─────────┬───────────┘
                    ┌─────────▼───────────┐
                    │ end_of_elaboration  │  Bottom-up
                    └─────────┬───────────┘
                    ┌─────────▼───────────┐
                    │ start_of_simulation │  Bottom-up
                    └─────────┬───────────┘
              ┌───────────────▼────────────────┐
              │         run_phase              │  Parallel
              │  ┌──────────────────────────┐  │  (task —
              │  │ reset → configure →      │  │  consumes
              │  │ main → shutdown          │  │  time)
              │  └──────────────────────────┘  │
              └───────────────┬────────────────┘
                    ┌─────────▼───────────┐
                    │   extract_phase     │  Bottom-up
                    └─────────┬───────────┘
                    ┌─────────▼───────────┐
                    │    check_phase      │  Bottom-up
                    └─────────┬───────────┘
                    ┌─────────▼───────────┐
                    │   report_phase      │  Bottom-up
                    └─────────┬───────────┘
                    ┌─────────▼───────────┐
                    │    final_phase      │  Top-down
                    └─────────────────────┘
```

### 19.2 Phase Categories

| Category | Phases | Execution |
|----------|--------|-----------|
| **Build** | `build_phase` | Top-down (parent before children) |
| **Connect** | `connect_phase`, `end_of_elaboration_phase` | Bottom-up |
| **Run** | `run_phase` (+ sub-phases: `reset`, `configure`, `main`, `shutdown`) | All components run in parallel (fork-join) |
| **Clean-up** | `extract_phase`, `check_phase`, `report_phase`, `final_phase` | Bottom-up |

### 19.3 Phase Method Signatures

**Function phases** (zero-time):

```systemverilog
virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    // create sub-components, get config
endfunction

virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    // connect TLM ports
endfunction
```

**Task phases** (consume simulation time):

```systemverilog
virtual task run_phase(uvm_phase phase);
    phase.raise_objection(this);   // prevent phase from ending
    // ... simulation activity ...
    phase.drop_objection(this);    // allow phase to end
endtask
```

### 19.4 Objections

Objections control when a phase ends. A phase ends when **all objections are dropped**:

```systemverilog
virtual task run_phase(uvm_phase phase);
    phase.raise_objection(this, "Starting test stimulus");

    repeat (100) begin
        apb_transaction tr = apb_transaction::type_id::create("tr");
        start_item(tr);
        tr.randomize();
        finish_item(tr);
    end

    phase.drop_objection(this, "Stimulus complete");
endtask
```

**Best practice:** Raise and drop objections in the test or sequence, not in drivers or monitors.

---

## 20. `uvm_transaction` and `uvm_sequence_item`

### 20.1 `uvm_transaction`

Extends `uvm_object` with timing information:

| Method | Purpose |
|--------|---------|
| `accept_tr()` | Mark transaction as accepted (timestamp) |
| `begin_tr()` | Mark start of transaction |
| `end_tr()` | Mark end of transaction |
| `get_begin_time()` | Return start time |
| `get_end_time()` | Return end time |

### 20.2 `uvm_sequence_item`

Extends `uvm_transaction` and adds sequence/sequencer awareness:

| Method | Purpose |
|--------|---------|
| `set_sequencer()` | Associate with a sequencer |
| `get_sequencer()` | Return the associated sequencer |
| `set_parent_sequence()` | Set parent sequence |
| `get_parent_sequence()` | Get parent sequence |
| `get_sequence_id()` | Get unique sequence ID |
| `set_item_context()` | Set both sequencer and parent sequence |

### 20.3 Complete Sequence Item Example

```systemverilog
class axi_transaction extends uvm_sequence_item;
    `uvm_object_utils(axi_transaction)

    // Address channel
    rand bit [31:0] addr;
    rand bit [3:0]  id;
    rand bit [7:0]  len;       // burst length - 1
    rand bit [2:0]  size;      // 2^size bytes per beat
    rand bit [1:0]  burst;     // FIXED=0, INCR=1, WRAP=2

    // Data channel
    rand bit [31:0] data[];
    rand bit [3:0]  strb[];

    // Response
    bit [1:0] resp;            // OKAY=0, EXOKAY=1, SLVERR=2, DECERR=3

    // Control
    rand bit write;

    // Constraints
    constraint valid_burst_c {
        len inside {[0:255]};
        size inside {[0:2]};     // up to 4 bytes
        burst inside {0, 1, 2};
    }

    constraint data_size_c {
        data.size() == len + 1;
        strb.size() == len + 1;
    }

    constraint aligned_addr_c {
        addr % (1 << size) == 0;
    }

    constraint wrap_constraint_c {
        (burst == 2) -> len inside {1, 3, 7, 15};
    }

    function new(string name = "axi_transaction");
        super.new(name);
    endfunction

    virtual function void do_copy(uvm_object rhs);
        axi_transaction rhs_;
        super.do_copy(rhs);
        $cast(rhs_, rhs);
        this.addr  = rhs_.addr;
        this.id    = rhs_.id;
        this.len   = rhs_.len;
        this.size  = rhs_.size;
        this.burst = rhs_.burst;
        this.data  = rhs_.data;
        this.strb  = rhs_.strb;
        this.resp  = rhs_.resp;
        this.write = rhs_.write;
    endfunction

    virtual function string convert2string();
        string s;
        s = $sformatf("AXI %s ID:%0d ADDR:0x%08h LEN:%0d SIZE:%0d BURST:%0d",
                       write ? "WR" : "RD", id, addr, len, size, burst);
        if (write) begin
            foreach (data[i])
                s = {s, $sformatf("\n  [%0d] data=0x%08h strb=0x%01h", i, data[i], strb[i])};
        end
        return s;
    endfunction
endclass
```

---

## 21. `uvm_sequence` — Stimulus Generation

A sequence generates a stream of sequence items (transactions) and sends them to a sequencer.

### 21.1 Key Methods

| Method | Purpose |
|--------|---------|
| `body()` | Main stimulus logic — override this |
| `start(sequencer, parent_sequence)` | Launch the sequence on a sequencer |
| `start_item(item)` | Request grant from sequencer |
| `finish_item(item)` | Send item to driver, wait for response |
| `create_item(type, sequencer, name)` | Factory-create a sequence item |
| `get_response(rsp)` | Get response from driver |
| `pre_body()` | Callback before `body()` |
| `post_body()` | Callback after `body()` |
| `pre_start()` | Callback before sequence starts |
| `post_start()` | Callback after sequence completes |

### 21.2 Sequence Item Flow: `start_item` / `finish_item`

```
Sequence                  Sequencer                 Driver
   │                          │                        │
   ├── start_item(item) ────►│                        │
   │   (wait for grant)       │                        │
   │◄─── grant ───────────────│                        │
   │                          │                        │
   │   randomize(item)        │                        │
   │                          │                        │
   ├── finish_item(item) ───►│──── item ─────────────►│
   │                          │                        │ drive_item()
   │◄── (return) ─────────────│◄─── done ──────────────│
   │                          │                        │
```

### 21.3 Simple Sequence

```systemverilog
class apb_write_seq extends uvm_sequence #(apb_transaction);
    `uvm_object_utils(apb_write_seq)

    rand bit [31:0] start_addr;
    rand int        num_writes;

    constraint defaults_c {
        num_writes inside {[1:20]};
    }

    function new(string name = "apb_write_seq");
        super.new(name);
    endfunction

    virtual task body();
        apb_transaction tr;

        for (int i = 0; i < num_writes; i++) begin
            tr = apb_transaction::type_id::create($sformatf("tr_%0d", i));
            start_item(tr);
            if (!tr.randomize() with {
                addr == start_addr + (i * 4);
                write == 1;
            })
                `uvm_error(get_type_name(), "Randomization failed")
            finish_item(tr);
            `uvm_info(get_type_name(), tr.convert2string(), UVM_MEDIUM)
        end
    endtask
endclass
```

### 21.4 Sequence of Sequences (Layered / Virtual Sequence)

```systemverilog
class full_test_vseq extends uvm_sequence #(uvm_sequence_item);
    `uvm_object_utils(full_test_vseq)

    apb_write_seq  write_seq;
    apb_read_seq   read_seq;
    apb_error_seq  error_seq;

    function new(string name = "full_test_vseq");
        super.new(name);
    endfunction

    virtual task body();
        // Phase 1: Write a block
        write_seq = apb_write_seq::type_id::create("write_seq");
        write_seq.start_addr = 32'h0000_0100;
        write_seq.num_writes = 10;
        write_seq.start(m_sequencer);

        // Phase 2: Read back and verify
        read_seq = apb_read_seq::type_id::create("read_seq");
        read_seq.start_addr = 32'h0000_0100;
        read_seq.num_reads  = 10;
        read_seq.start(m_sequencer);

        // Phase 3: Error injection
        error_seq = apb_error_seq::type_id::create("error_seq");
        error_seq.start(m_sequencer);
    endtask
endclass
```

---

## 22. `uvm_driver` — Driving the DUT

The driver receives sequence items from the sequencer and drives them onto the DUT interface.

### 22.1 Key Methods

| Method | Purpose |
|--------|---------|
| `new(string name, uvm_component parent)` | Constructor |
| `build_phase()` | Get virtual interface from config |
| `run_phase()` | Main driving loop |
| `seq_item_port` | Built-in TLM port to pull items from the sequencer |
| `seq_item_port.get_next_item(req)` | Blocking: get next item from sequencer |
| `seq_item_port.item_done(rsp)` | Signal completion, optionally send response |
| `seq_item_port.try_next_item(req)` | Non-blocking: returns null if no item available |
| `seq_item_port.get(req)` | Get + automatic item_done |
| `seq_item_port.put(rsp)` | Send response |
| `rsp_port` | Optional response port |

### 22.2 Complete Driver Example

```systemverilog
class apb_driver extends uvm_driver #(apb_transaction);
    `uvm_component_utils(apb_driver)

    virtual apb_if vif;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db #(virtual apb_if)::get(this, "", "vif", vif))
            `uvm_fatal(get_type_name(), "Failed to get virtual interface")
    endfunction

    virtual task run_phase(uvm_phase phase);
        apb_transaction tr;

        // Initialize bus signals
        vif.psel    <= 0;
        vif.penable <= 0;
        vif.pwrite  <= 0;
        vif.paddr   <= 0;
        vif.pwdata  <= 0;

        forever begin
            seq_item_port.get_next_item(tr);
            drive_transaction(tr);
            seq_item_port.item_done();
        end
    endtask

    virtual task drive_transaction(apb_transaction tr);
        // Setup phase
        @(posedge vif.pclk);
        vif.psel   <= 1;
        vif.pwrite <= tr.write;
        vif.paddr  <= tr.addr;
        if (tr.write)
            vif.pwdata <= tr.data;

        // Access phase
        @(posedge vif.pclk);
        vif.penable <= 1;

        // Wait for ready
        @(posedge vif.pclk iff vif.pready);
        if (!tr.write)
            tr.data = vif.prdata;

        // Deassert
        vif.psel    <= 0;
        vif.penable <= 0;
    endtask
endclass
```

### 22.3 Pipelining: `get_next_item` vs `get` vs `try_next_item`

| Method | Blocking? | Auto `item_done`? | Use Case |
|--------|-----------|-------------------|----------|
| `get_next_item(req)` + `item_done()` | Yes | No (manual) | Standard request-response |
| `get(req)` | Yes | Yes (automatic) | Fire-and-forget |
| `try_next_item(req)` + `item_done()` | No | No (manual) | Idle cycle insertion |

---

## 23. `uvm_sequencer` — Arbitration

The sequencer routes sequence items from sequences to the driver.

### 23.1 Key Concepts

| Feature | Description |
|---------|-------------|
| `seq_item_export` | TLM export connected to the driver's `seq_item_port` |
| Arbitration | Controls which sequence gets access when multiple sequences run simultaneously |
| Lock/Grab | Exclusive access mechanisms |

### 23.2 Arbitration Modes

```systemverilog
// Set arbitration mode in the sequencer
my_sequencer.set_arbitration(UVM_SEQ_ARB_FIFO);       // Default: first-come-first-served
my_sequencer.set_arbitration(UVM_SEQ_ARB_RANDOM);      // Random among pending
my_sequencer.set_arbitration(UVM_SEQ_ARB_STRICT_FIFO); // Priority-based FIFO
my_sequencer.set_arbitration(UVM_SEQ_ARB_STRICT_RANDOM);// Priority-based random
my_sequencer.set_arbitration(UVM_SEQ_ARB_WEIGHTED);    // Weighted random
my_sequencer.set_arbitration(UVM_SEQ_ARB_USER);        // Custom user arbitration
```

### 23.3 Lock and Grab

```systemverilog
class priority_seq extends uvm_sequence #(apb_transaction);
    virtual task body();
        // Lock: waits for current item to complete, then takes exclusive access
        lock(m_sequencer);
        // ... send items with exclusive access ...
        unlock(m_sequencer);

        // Grab: takes effect immediately (higher priority than lock)
        grab(m_sequencer);
        // ... send urgent items ...
        ungrab(m_sequencer);
    endtask
endclass
```

### 23.4 Basic Sequencer (usually just typedef or minimal extension)

```systemverilog
class apb_sequencer extends uvm_sequencer #(apb_transaction);
    `uvm_component_utils(apb_sequencer)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction
endclass
```

Most sequencers need no customization — the base `uvm_sequencer` handles everything.

---

## 24. `uvm_monitor` — Passive Observation

The monitor samples DUT interface signals and broadcasts observed transactions to subscribers (scoreboards, coverage collectors) via an analysis port.

### 24.1 Key Features

| Feature | Description |
|---------|-------------|
| Passive | Does not drive any signals |
| Analysis port | Broadcasts transactions to all subscribers |
| Coverage | Can contain functional coverage |
| Protocol checking | Can include protocol assertion checks |

### 24.2 Complete Monitor Example

```systemverilog
class apb_monitor extends uvm_monitor;
    `uvm_component_utils(apb_monitor)

    virtual apb_if vif;
    uvm_analysis_port #(apb_transaction) analysis_port;

    // Optional: functional coverage
    covergroup apb_cg;
        addr_cp:   coverpoint trans_collected.addr  { bins ranges[] = {[0:32'hFFFF]}; }
        write_cp:  coverpoint trans_collected.write;
        cross addr_cp, write_cp;
    endgroup

    apb_transaction trans_collected;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        analysis_port = new("analysis_port", this);
        trans_collected = new("trans_collected");
        if (!uvm_config_db #(virtual apb_if)::get(this, "", "vif", vif))
            `uvm_fatal(get_type_name(), "Failed to get virtual interface")
        apb_cg = new();
    endfunction

    virtual task run_phase(uvm_phase phase);
        forever begin
            collect_transaction();
        end
    endtask

    virtual task collect_transaction();
        // Wait for a valid APB transfer
        @(posedge vif.pclk iff (vif.psel && vif.penable && vif.pready));
        trans_collected.addr  = vif.paddr;
        trans_collected.write = vif.pwrite;
        trans_collected.data  = vif.pwrite ? vif.pwdata : vif.prdata;

        // Sample coverage
        apb_cg.sample();

        // Broadcast to subscribers
        analysis_port.write(trans_collected);

        `uvm_info(get_type_name(), $sformatf("Observed: %s",
                  trans_collected.convert2string()), UVM_HIGH)
    endtask
endclass
```

---

## 25. `uvm_agent` — Grouping Driver, Sequencer, Monitor

An agent bundles the driver, sequencer, and monitor for a single interface. It can operate in **active** mode (drives and monitors) or **passive** mode (monitors only).

### 25.1 Key Concepts

| Feature | Description |
|---------|-------------|
| `is_active` | `UVM_ACTIVE` (has driver + sequencer) or `UVM_PASSIVE` (monitor only) |
| Encapsulation | Wraps a complete interface protocol |
| Reusability | Same agent used in many testbenches |

### 25.2 Complete Agent Example

```systemverilog
class apb_agent extends uvm_agent;
    `uvm_component_utils(apb_agent)

    apb_driver     drv;
    apb_sequencer  sqr;
    apb_monitor    mon;

    uvm_analysis_port #(apb_transaction) ap;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        // Monitor is always created
        mon = apb_monitor::type_id::create("mon", this);

        // Driver and sequencer only in active mode
        if (get_is_active() == UVM_ACTIVE) begin
            drv = apb_driver::type_id::create("drv", this);
            sqr = apb_sequencer::type_id::create("sqr", this);
        end
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        // Connect monitor's analysis port to agent-level port
        ap = mon.analysis_port;

        // Connect driver to sequencer
        if (get_is_active() == UVM_ACTIVE) begin
            drv.seq_item_port.connect(sqr.seq_item_export);
        end
    endfunction
endclass
```

### 25.3 Setting Active/Passive Mode

```systemverilog
// In the environment's build_phase:
uvm_config_db #(uvm_active_passive_enum)::set(this, "agt", "is_active", UVM_PASSIVE);
```

Or override from the test:

```systemverilog
function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    uvm_config_db #(uvm_active_passive_enum)::set(this, "env.agt", "is_active", UVM_ACTIVE);
endfunction
```

---

## 26. `uvm_scoreboard` — Checking Results

The scoreboard compares actual DUT outputs against expected values. It connects to monitors via analysis ports.

### 26.1 Key Pattern: `uvm_analysis_imp` with `write()` callback

```systemverilog
class apb_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(apb_scoreboard)

    uvm_analysis_imp #(apb_transaction, apb_scoreboard) analysis_imp;

    // Reference model — simple associative memory
    bit [31:0] memory[bit [31:0]];

    int num_writes;
    int num_reads;
    int num_matches;
    int num_mismatches;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        analysis_imp = new("analysis_imp", this);
    endfunction

    // Called automatically whenever the monitor writes to its analysis port
    virtual function void write(apb_transaction tr);
        if (tr.write) begin
            memory[tr.addr] = tr.data;
            num_writes++;
            `uvm_info(get_type_name(), $sformatf("WRITE: addr=0x%08h data=0x%08h",
                      tr.addr, tr.data), UVM_HIGH)
        end else begin
            num_reads++;
            if (memory.exists(tr.addr)) begin
                if (tr.data == memory[tr.addr]) begin
                    num_matches++;
                    `uvm_info(get_type_name(), $sformatf(
                        "MATCH: addr=0x%08h expected=0x%08h got=0x%08h",
                        tr.addr, memory[tr.addr], tr.data), UVM_MEDIUM)
                end else begin
                    num_mismatches++;
                    `uvm_error(get_type_name(), $sformatf(
                        "MISMATCH: addr=0x%08h expected=0x%08h got=0x%08h",
                        tr.addr, memory[tr.addr], tr.data))
                end
            end else begin
                `uvm_warning(get_type_name(), $sformatf(
                    "READ from uninitialized address 0x%08h", tr.addr))
            end
        end
    endfunction

    virtual function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info(get_type_name(), $sformatf(
            "\n--- Scoreboard Summary ---\nWrites:     %0d\nReads:      %0d\nMatches:    %0d\nMismatches: %0d",
            num_writes, num_reads, num_matches, num_mismatches), UVM_LOW)
    endfunction
endclass
```

### 26.2 Multiple Analysis Ports with `uvm_analysis_imp_decl`

When a scoreboard needs to receive from multiple monitors, use the declaration macro:

```systemverilog
`uvm_analysis_imp_decl(_expected)
`uvm_analysis_imp_decl(_actual)

class dual_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(dual_scoreboard)

    uvm_analysis_imp_expected #(apb_transaction, dual_scoreboard) expected_imp;
    uvm_analysis_imp_actual   #(apb_transaction, dual_scoreboard) actual_imp;

    apb_transaction expected_queue[$];

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        expected_imp = new("expected_imp", this);
        actual_imp   = new("actual_imp", this);
    endfunction

    // Called when reference model writes to expected port
    function void write_expected(apb_transaction tr);
        expected_queue.push_back(tr);
    endfunction

    // Called when DUT monitor writes to actual port
    function void write_actual(apb_transaction tr);
        apb_transaction exp;
        if (expected_queue.size() == 0) begin
            `uvm_error(get_type_name(), "Received actual with no expected!")
            return;
        end
        exp = expected_queue.pop_front();
        if (!tr.compare(exp))
            `uvm_error(get_type_name(), $sformatf(
                "Mismatch!\n  Expected: %s\n  Actual:   %s",
                exp.convert2string(), tr.convert2string()))
        else
            `uvm_info(get_type_name(), "Match!", UVM_HIGH)
    endfunction
endclass
```

---

## 27. `uvm_env` — Top-Level Environment

The environment is the container that holds agents, scoreboards, and other sub-environments.

```systemverilog
class apb_env extends uvm_env;
    `uvm_component_utils(apb_env)

    apb_agent      agent;
    apb_scoreboard scoreboard;
    apb_coverage   coverage;      // optional coverage collector

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        agent      = apb_agent::type_id::create("agent", this);
        scoreboard = apb_scoreboard::type_id::create("scoreboard", this);
        coverage   = apb_coverage::type_id::create("coverage", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        // Connect monitor output to scoreboard and coverage
        agent.ap.connect(scoreboard.analysis_imp);
        agent.ap.connect(coverage.analysis_export);
    endfunction
endclass
```

### Multi-Agent Environment

```systemverilog
class soc_env extends uvm_env;
    `uvm_component_utils(soc_env)

    apb_agent      apb_agt;
    axi_agent      axi_agt;
    uart_agent     uart_agt;
    soc_scoreboard sb;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        apb_agt  = apb_agent::type_id::create("apb_agt", this);
        axi_agt  = axi_agent::type_id::create("axi_agt", this);
        uart_agt = uart_agent::type_id::create("uart_agt", this);
        sb       = soc_scoreboard::type_id::create("sb", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        apb_agt.ap.connect(sb.apb_imp);
        axi_agt.ap.connect(sb.axi_imp);
        uart_agt.ap.connect(sb.uart_imp);
    endfunction
endclass
```

---

## 28. `uvm_test` — Test Entry Point

The test is the top of the UVM component hierarchy. It creates the environment and starts sequences.

### 28.1 Key Responsibilities

1. Create and configure the environment.
2. Set factory overrides.
3. Set configuration values.
4. Start sequences via `run_phase`.

### 28.2 Complete Test Example

```systemverilog
class apb_base_test extends uvm_test;
    `uvm_component_utils(apb_base_test)

    apb_env env;

    function new(string name = "apb_base_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = apb_env::type_id::create("env", this);

        // Pass the virtual interface down through config_db
        // (set in the top-level module, retrieved by the driver/monitor)
    endfunction

    virtual function void end_of_elaboration_phase(uvm_phase phase);
        super.end_of_elaboration_phase(phase);
        uvm_top.print_topology();  // print component tree
    endfunction

    virtual task run_phase(uvm_phase phase);
        // Base test does nothing — subclasses override
    endtask

    virtual function void report_phase(uvm_phase phase);
        uvm_report_server svr = uvm_report_server::get_server();
        if (svr.get_severity_count(UVM_ERROR) > 0)
            `uvm_info(get_type_name(), "*** TEST FAILED ***", UVM_NONE)
        else
            `uvm_info(get_type_name(), "*** TEST PASSED ***", UVM_NONE)
    endfunction
endclass

class apb_write_test extends apb_base_test;
    `uvm_component_utils(apb_write_test)

    function new(string name = "apb_write_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual task run_phase(uvm_phase phase);
        apb_write_seq seq;

        phase.raise_objection(this);
        seq = apb_write_seq::type_id::create("seq");
        seq.start_addr = 32'h0000_0000;
        seq.num_writes = 50;
        seq.start(env.agent.sqr);
        phase.drop_objection(this);
    endtask
endclass
```

### 28.3 Running a Specific Test

From the simulator command line:

```bash
# Questa/ModelSim
vsim +UVM_TESTNAME=apb_write_test

# VCS
simv +UVM_TESTNAME=apb_write_test

# Xcelium
xrun +UVM_TESTNAME=apb_write_test
```

The top-level module runs UVM:

```systemverilog
module top;
    apb_if apb_bus(clk);

    dut_wrapper dut(.bus(apb_bus));

    initial begin
        uvm_config_db #(virtual apb_if)::set(null, "*.agent.*", "vif", apb_bus);
        run_test();  // UVM picks the test from +UVM_TESTNAME
    end
endmodule
```

---

## 29. The UVM Factory

The factory is a design pattern that decouples **object creation** from **object type**. Instead of calling `new()` directly, you ask the factory to create objects, and it can transparently substitute a derived type.

### 29.1 Registering with the Factory

Every UVM class must be registered:

```systemverilog
// For uvm_object-derived classes (transactions, sequences):
class my_transaction extends uvm_sequence_item;
    `uvm_object_utils(my_transaction)      // registers with factory
    // ...
endclass

// For uvm_component-derived classes (drivers, monitors, agents):
class my_driver extends uvm_driver #(my_transaction);
    `uvm_component_utils(my_driver)        // registers with factory
    // ...
endclass
```

### 29.2 Creating Objects via the Factory

```systemverilog
// Instead of:
my_transaction tr = new("tr");            // WRONG — bypasses factory

// Use:
my_transaction tr = my_transaction::type_id::create("tr");          // object
my_driver      drv = my_driver::type_id::create("drv", this);      // component
```

### 29.3 Factory Overrides

**Type override** — globally replace one type with another:

```systemverilog
class error_transaction extends my_transaction;
    `uvm_object_utils(error_transaction)
    // adds error injection fields and constraints
endclass

// In the test:
function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    // Every create() of my_transaction now returns error_transaction
    my_transaction::type_id::set_type_override(error_transaction::get_type());
endfunction
```

**Instance override** — replace only for a specific component path:

```systemverilog
// Only the driver's transactions become error_transaction
my_transaction::type_id::set_inst_override(
    error_transaction::get_type(),
    "uvm_test_top.env.agent.drv.*"
);
```

**Using `set_type_override_by_type` and `set_inst_override_by_type`:**

```systemverilog
// Type override
factory.set_type_override_by_type(
    my_driver::get_type(),
    enhanced_driver::get_type()
);

// Instance override
factory.set_inst_override_by_type(
    my_driver::get_type(),
    enhanced_driver::get_type(),
    "uvm_test_top.env.agent.drv"
);
```

### 29.4 Factory Debug

```systemverilog
factory.print();  // print all registered types and overrides
```

---

## 30. Configuration Database — `uvm_config_db`

`uvm_config_db` provides hierarchical, type-safe configuration passing between components.

### 30.1 API

```systemverilog
// SET a value (typically in a parent or test)
uvm_config_db #(T)::set(context, inst_name, field_name, value);

// GET a value (typically in the component that needs it)
uvm_config_db #(T)::get(context, inst_name, field_name, variable);

// EXISTS check
uvm_config_db #(T)::exists(context, inst_name, field_name);
```

### 30.2 Common Patterns

**Passing a virtual interface:**

```systemverilog
// In top-level module:
initial begin
    uvm_config_db #(virtual apb_if)::set(null, "uvm_test_top.env.agent.*", "vif", apb_bus);
end

// In driver or monitor:
virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(virtual apb_if)::get(this, "", "vif", vif))
        `uvm_fatal("CONFIG", "Cannot find 'vif' in config_db")
endfunction
```

**Passing configuration objects:**

```systemverilog
class apb_config extends uvm_object;
    `uvm_object_utils(apb_config)

    bit        has_coverage = 1;
    int        num_agents   = 1;
    bit [31:0] base_addr    = 32'h0;

    function new(string name = "apb_config");
        super.new(name);
    endfunction
endclass

// In the test:
function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    apb_config cfg = apb_config::type_id::create("cfg");
    cfg.has_coverage = 0;
    cfg.base_addr    = 32'h1000_0000;
    uvm_config_db #(apb_config)::set(this, "env", "cfg", cfg);
endfunction

// In the env:
function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    apb_config cfg;
    if (!uvm_config_db #(apb_config)::get(this, "", "cfg", cfg))
        `uvm_fatal("CONFIG", "No config found")
    if (cfg.has_coverage)
        cov = apb_coverage::type_id::create("cov", this);
endfunction
```

### 30.3 Scope Rules

The `set` context + instance path determines which components can see the value. UVM searches from the most specific match to the broadest:

```systemverilog
// Visible to all components:
uvm_config_db #(int)::set(null, "*", "timeout", 1000);

// Visible only to the agent and its children:
uvm_config_db #(int)::set(this, "agent.*", "timeout", 500);

// Visible only to the driver:
uvm_config_db #(int)::set(this, "agent.drv", "timeout", 200);
```

### 30.4 Debug

```systemverilog
// Enable config_db tracing via command line:
// +UVM_CONFIG_DB_TRACE
```

---

## 31. TLM Ports and Communication

UVM uses Transaction-Level Modeling (TLM) for inter-component communication. This decouples producers from consumers.

### 31.1 Port Types

| Port Type | Direction | Cardinality |
|-----------|-----------|-------------|
| `uvm_analysis_port` | Producer → Subscribers | 1-to-many (broadcast) |
| `uvm_analysis_imp` | Receives from analysis port | 1-to-1 (subscriber end) |
| `uvm_analysis_export` | Passes through to imp | Hierarchical passthrough |
| `uvm_tlm_fifo` | Buffered FIFO | 1-to-1 |
| `uvm_blocking_put_port` | Blocking put | 1-to-1 |
| `uvm_blocking_get_port` | Blocking get | 1-to-1 |
| `uvm_nonblocking_put_port` | Non-blocking put | 1-to-1 |
| `uvm_nonblocking_get_port` | Non-blocking get | 1-to-1 |

### 31.2 Analysis Port / Imp Pattern

This is the most common communication pattern in UVM.

```
                          ┌──────────────┐
                          │ Scoreboard   │
    ┌─────────┐   write() │ write() {    │
    │ Monitor ├──────────►│   compare... │
    │         │           │ }            │
    └─────────┘           └──────────────┘
   analysis_port          analysis_imp
```

```systemverilog
// Producer (monitor):
uvm_analysis_port #(my_transaction) ap;
ap = new("ap", this);
// ... after observing a transaction:
ap.write(tr);  // broadcasts to all connected imps

// Consumer (scoreboard):
uvm_analysis_imp #(my_transaction, my_scoreboard) imp;
imp = new("imp", this);
// Must implement:
function void write(my_transaction tr);
    // process the transaction
endfunction
```

### 31.3 TLM FIFO

A `uvm_tlm_analysis_fifo` buffers transactions between a producer and consumer:

```systemverilog
class my_scoreboard extends uvm_scoreboard;
    uvm_tlm_analysis_fifo #(my_transaction) expected_fifo;
    uvm_tlm_analysis_fifo #(my_transaction) actual_fifo;

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        expected_fifo = new("expected_fifo", this);
        actual_fifo   = new("actual_fifo", this);
    endfunction

    virtual task run_phase(uvm_phase phase);
        my_transaction exp_tr, act_tr;
        forever begin
            expected_fifo.get(exp_tr);
            actual_fifo.get(act_tr);
            if (!exp_tr.compare(act_tr))
                `uvm_error(get_type_name(), "Mismatch!")
        end
    endtask
endclass
```

### 31.4 Connection Rules

- `port.connect(export)` or `port.connect(imp)` — always **port** connects **to** export/imp.
- An `analysis_port` can connect to multiple `analysis_imp` or `analysis_export`.
- Connections are made in `connect_phase`.

---

## 32. UVM Reporting and Messaging

UVM provides a unified reporting system with severity, verbosity, and configurable actions.

### 32.1 Messaging Macros

```systemverilog
`uvm_info(ID, MSG, VERBOSITY)
`uvm_warning(ID, MSG)
`uvm_error(ID, MSG)
`uvm_fatal(ID, MSG)
```

| Severity | Default Action | Purpose |
|----------|---------------|---------|
| `UVM_INFO` | Display | Informational message |
| `UVM_WARNING` | Display | Potential problem |
| `UVM_ERROR` | Display + Count | Definite problem, may continue |
| `UVM_FATAL` | Display + Exit | Unrecoverable error, simulation aborts |

### 32.2 Verbosity Levels

```systemverilog
`uvm_info("DRIVER", "Driving transaction", UVM_MEDIUM)    // printed at medium+
`uvm_info("DRIVER", "Transaction details", UVM_HIGH)      // printed only at high+
`uvm_info("DRIVER", "Bit-level debug", UVM_DEBUG)         // printed only at debug
```

| Level | Value | Description |
|-------|-------|-------------|
| `UVM_NONE` | 0 | Always printed |
| `UVM_LOW` | 100 | Major events |
| `UVM_MEDIUM` | 200 | Standard detail (default) |
| `UVM_HIGH` | 300 | Detailed trace |
| `UVM_FULL` | 400 | Very detailed |
| `UVM_DEBUG` | 500 | Debug only |

**Setting verbosity from the command line:**

```bash
+UVM_VERBOSITY=UVM_HIGH         # all components
+uvm_set_verbosity=*driver*,_ALL_,UVM_DEBUG,run   # specific component
```

### 32.3 Report Server Customization

```systemverilog
// Limit errors before simulation stops:
uvm_report_server svr = uvm_report_server::get_server();
svr.set_max_quit_count(10);  // stop after 10 errors

// Demote an error to a warning:
set_report_severity_id_override(UVM_ERROR, "EXPECTED_ERR", UVM_WARNING);

// Set action: UVM_NO_ACTION, UVM_DISPLAY, UVM_LOG, UVM_COUNT, UVM_EXIT, UVM_CALL_HOOK
set_report_severity_action(UVM_WARNING, UVM_DISPLAY | UVM_LOG);
```

---

## 33. Field Automation Macros — `uvm_field_*`

Field macros automatically implement `copy`, `compare`, `print`, `pack`, and `unpack` for registered fields. While convenient, they have performance overhead and are optional.

### 33.1 Available Macros

```systemverilog
class my_transaction extends uvm_sequence_item;
    `uvm_object_utils_begin(my_transaction)
        `uvm_field_int(addr,      UVM_ALL_ON)
        `uvm_field_int(data,      UVM_ALL_ON)
        `uvm_field_int(write,     UVM_ALL_ON | UVM_BIN)
        `uvm_field_string(name,   UVM_ALL_ON)
        `uvm_field_enum(op_e, op, UVM_ALL_ON)
        `uvm_field_object(cfg,    UVM_ALL_ON)
        `uvm_field_queue_int(data_q, UVM_ALL_ON)
        `uvm_field_array_int(data_a, UVM_ALL_ON)
        `uvm_field_sarray_int(data_sa, UVM_ALL_ON)
        `uvm_field_aa_int_string(map, UVM_ALL_ON)
    `uvm_object_utils_end

    rand bit [31:0] addr;
    rand bit [31:0] data;
    rand bit        write;
    string          name;
    op_e            op;
    my_config       cfg;
    int             data_q[$];
    bit [7:0]       data_a[];
    bit [7:0]       data_sa[4];
    int             map[string];
endclass
```

### 33.2 Field Flags

| Flag | Meaning |
|------|---------|
| `UVM_ALL_ON` | Enable all operations |
| `UVM_NOPRINT` | Exclude from print |
| `UVM_NOCOMPARE` | Exclude from compare |
| `UVM_NOCOPY` | Exclude from copy |
| `UVM_NOPACK` | Exclude from pack/unpack |
| `UVM_HEX`, `UVM_DEC`, `UVM_BIN`, `UVM_OCT` | Print radix |
| `UVM_READONLY` | Not settable via `set_*` |

### 33.3 Field Macros vs Manual `do_*` Methods

| Aspect | Field Macros | Manual `do_*` |
|--------|-------------|---------------|
| Code size | Minimal | More code |
| Performance | Slower (macro expansion overhead) | Faster |
| Control | Limited | Full control |
| Debugging | Harder to trace | Easier to debug |
| Recommendation | Prototyping / simple objects | Production / complex objects |

**Best practice:** Use manual `do_copy()`, `do_compare()`, and `do_print()` in performance-sensitive code. Use field macros for quick prototyping.

---

## 34. Register Abstraction Layer (RAL) Overview

The UVM RAL provides a high-level abstraction of DUT registers, enabling register access from sequences without hardcoding addresses.

### 34.1 RAL Class Hierarchy

```
uvm_reg_block
├── uvm_reg
│   └── uvm_reg_field
├── uvm_reg_map
└── uvm_mem
```

### 34.2 Register Model Example

```systemverilog
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

        //                     parent  size  lsb  access    reset  has_reset
        enable.configure  (this,   1,    0, "RW",    0,  1'b0,     1, 0, 1);
        mode.configure    (this,   2,    1, "RW",    0,  2'b00,    1, 0, 1);
        irq_mask.configure(this,   8,    8, "RW",    0,  8'h00,    1, 0, 1);
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
        irq_status.configure(this, 8, 8, "RO", 1, 8'h00, 1, 0, 0);
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

        default_map = create_map("default_map", 0, 4, UVM_LITTLE_ENDIAN);
        default_map.add_reg(ctrl,   32'h0000, "RW");
        default_map.add_reg(status, 32'h0004, "RO");
    endfunction
endclass
```

### 34.3 Using RAL in Sequences

```systemverilog
class reg_test_seq extends uvm_reg_sequence;
    `uvm_object_utils(reg_test_seq)

    my_reg_block reg_model;

    function new(string name = "reg_test_seq");
        super.new(name);
    endfunction

    virtual task body();
        uvm_status_e status;
        uvm_reg_data_t data;

        // Write via field access
        reg_model.ctrl.enable.set(1);
        reg_model.ctrl.mode.set(2'b01);
        reg_model.ctrl.update(status);

        // Read back
        reg_model.ctrl.read(status, data);
        `uvm_info(get_type_name(), $sformatf("CTRL = 0x%08h", data), UVM_LOW)

        // Write via register write
        reg_model.ctrl.write(status, 32'h0000_0103);

        // Mirror (read and compare with model)
        reg_model.status.mirror(status, UVM_CHECK);

        // Peek/Poke (backdoor access)
        reg_model.status.peek(status, data);
        reg_model.ctrl.poke(status, 32'hFF);
    endtask
endclass
```

### 34.4 Key RAL Methods

| Method | Description |
|--------|-------------|
| `write(status, data)` | Frontdoor register write |
| `read(status, data)` | Frontdoor register read |
| `set(value)` | Set the desired value (field level) |
| `get()` | Get the desired value |
| `update(status)` | Write only changed fields |
| `mirror(status, check)` | Read and optionally compare with model |
| `peek(status, data)` | Backdoor read (no bus access) |
| `poke(status, data)` | Backdoor write (no bus access) |
| `reset()` | Reset to default values |
| `get_mirrored_value()` | Get last known value |

---

# Part III — Putting It All Together

---

## 35. Complete UVM Testbench Walkthrough

This section shows a complete, working UVM testbench for a simple APB memory slave.

### 35.1 DUT — Simple APB Memory

```systemverilog
module apb_memory #(
    parameter ADDR_WIDTH = 8,
    parameter DATA_WIDTH = 32
)(
    input  logic                    pclk,
    input  logic                    preset_n,
    input  logic                    psel,
    input  logic                    penable,
    input  logic                    pwrite,
    input  logic [ADDR_WIDTH-1:0]   paddr,
    input  logic [DATA_WIDTH-1:0]   pwdata,
    output logic [DATA_WIDTH-1:0]   prdata,
    output logic                    pready,
    output logic                    pslverr
);

    logic [DATA_WIDTH-1:0] mem [0:(1<<ADDR_WIDTH)-1];

    typedef enum logic [1:0] {IDLE, SETUP, ACCESS} state_e;
    state_e state, next_state;

    always_ff @(posedge pclk or negedge preset_n) begin
        if (!preset_n)
            state <= IDLE;
        else
            state <= next_state;
    end

    always_comb begin
        next_state = state;
        case (state)
            IDLE:    if (psel && !penable)  next_state = SETUP;
            SETUP:   if (psel && penable)   next_state = ACCESS;
            ACCESS:  next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    assign pready  = (state == ACCESS);
    assign pslverr = 1'b0;

    always_ff @(posedge pclk) begin
        if (state == ACCESS && pwrite)
            mem[paddr] <= pwdata;
    end

    assign prdata = (state == ACCESS && !pwrite) ? mem[paddr] : '0;
endmodule
```

### 35.2 APB Interface

```systemverilog
interface apb_if(input logic pclk);
    logic        preset_n;
    logic        psel;
    logic        penable;
    logic        pwrite;
    logic [7:0]  paddr;
    logic [31:0] pwdata;
    logic [31:0] prdata;
    logic        pready;
    logic        pslverr;

    clocking drv_cb @(posedge pclk);
        output psel, penable, pwrite, paddr, pwdata;
        input  prdata, pready, pslverr;
    endclocking

    clocking mon_cb @(posedge pclk);
        input psel, penable, pwrite, paddr, pwdata, prdata, pready, pslverr;
    endclocking

    modport driver  (clocking drv_cb, input pclk, output preset_n);
    modport monitor (clocking mon_cb, input pclk, input preset_n);
endinterface
```

### 35.3 Transaction

```systemverilog
class apb_txn extends uvm_sequence_item;
    `uvm_object_utils(apb_txn)

    rand bit [7:0]  addr;
    rand bit [31:0] data;
    rand bit        write;

    constraint valid_addr_c {
        addr < 256;
    }

    function new(string name = "apb_txn");
        super.new(name);
    endfunction

    virtual function void do_copy(uvm_object rhs);
        apb_txn t;
        super.do_copy(rhs);
        $cast(t, rhs);
        addr  = t.addr;
        data  = t.data;
        write = t.write;
    endfunction

    virtual function bit do_compare(uvm_object rhs, uvm_comparer comparer);
        apb_txn t;
        bit eq;
        eq = super.do_compare(rhs, comparer);
        $cast(t, rhs);
        eq &= (addr  == t.addr);
        eq &= (data  == t.data);
        eq &= (write == t.write);
        return eq;
    endfunction

    virtual function string convert2string();
        return $sformatf("%s ADDR=0x%02h DATA=0x%08h",
                         write ? "WR" : "RD", addr, data);
    endfunction
endclass
```

### 35.4 Sequences

```systemverilog
class apb_write_seq extends uvm_sequence #(apb_txn);
    `uvm_object_utils(apb_write_seq)

    rand int num_txns;
    constraint c_num { num_txns inside {[5:20]}; }

    function new(string name = "apb_write_seq");
        super.new(name);
    endfunction

    virtual task body();
        apb_txn tr;
        repeat (num_txns) begin
            tr = apb_txn::type_id::create("tr");
            start_item(tr);
            assert(tr.randomize() with { write == 1; });
            finish_item(tr);
        end
    endtask
endclass

class apb_read_seq extends uvm_sequence #(apb_txn);
    `uvm_object_utils(apb_read_seq)

    bit [7:0] addrs[$];

    function new(string name = "apb_read_seq");
        super.new(name);
    endfunction

    virtual task body();
        apb_txn tr;
        foreach (addrs[i]) begin
            tr = apb_txn::type_id::create("tr");
            start_item(tr);
            assert(tr.randomize() with {
                addr  == addrs[i];
                write == 0;
            });
            finish_item(tr);
        end
    endtask
endclass

class apb_wr_rd_seq extends uvm_sequence #(apb_txn);
    `uvm_object_utils(apb_wr_rd_seq)

    rand int num_pairs;
    constraint c_pairs { num_pairs inside {[5:15]}; }

    function new(string name = "apb_wr_rd_seq");
        super.new(name);
    endfunction

    virtual task body();
        apb_txn wr_tr, rd_tr;
        bit [7:0] written_addrs[$];

        // Write phase
        repeat (num_pairs) begin
            wr_tr = apb_txn::type_id::create("wr_tr");
            start_item(wr_tr);
            assert(wr_tr.randomize() with { write == 1; });
            finish_item(wr_tr);
            written_addrs.push_back(wr_tr.addr);
        end

        // Read-back phase
        foreach (written_addrs[i]) begin
            rd_tr = apb_txn::type_id::create("rd_tr");
            start_item(rd_tr);
            assert(rd_tr.randomize() with {
                addr  == written_addrs[i];
                write == 0;
            });
            finish_item(rd_tr);
        end
    endtask
endclass
```

### 35.5 Driver

```systemverilog
class apb_drv extends uvm_driver #(apb_txn);
    `uvm_component_utils(apb_drv)

    virtual apb_if vif;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db #(virtual apb_if)::get(this, "", "vif", vif))
            `uvm_fatal(get_type_name(), "No virtual interface found")
    endfunction

    virtual task run_phase(uvm_phase phase);
        apb_txn tr;

        // Initialize
        vif.drv_cb.psel    <= 0;
        vif.drv_cb.penable <= 0;
        @(posedge vif.preset_n);   // wait for reset deassertion

        forever begin
            seq_item_port.get_next_item(tr);
            drive(tr);
            seq_item_port.item_done();
        end
    endtask

    virtual task drive(apb_txn tr);
        // Setup phase
        @(vif.drv_cb);
        vif.drv_cb.psel   <= 1;
        vif.drv_cb.pwrite <= tr.write;
        vif.drv_cb.paddr  <= tr.addr;
        if (tr.write)
            vif.drv_cb.pwdata <= tr.data;

        // Access phase
        @(vif.drv_cb);
        vif.drv_cb.penable <= 1;

        // Wait for ready
        do @(vif.drv_cb);
        while (!vif.drv_cb.pready);

        // Capture read data
        if (!tr.write)
            tr.data = vif.drv_cb.prdata;

        // Deassert
        vif.drv_cb.psel    <= 0;
        vif.drv_cb.penable <= 0;

        `uvm_info(get_type_name(), {"Driven: ", tr.convert2string()}, UVM_HIGH)
    endtask
endclass
```

### 35.6 Monitor

```systemverilog
class apb_mon extends uvm_monitor;
    `uvm_component_utils(apb_mon)

    virtual apb_if vif;
    uvm_analysis_port #(apb_txn) ap;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        ap = new("ap", this);
        if (!uvm_config_db #(virtual apb_if)::get(this, "", "vif", vif))
            `uvm_fatal(get_type_name(), "No virtual interface found")
    endfunction

    virtual task run_phase(uvm_phase phase);
        forever collect();
    endtask

    virtual task collect();
        apb_txn tr;

        // Wait for valid transfer completion
        @(vif.mon_cb iff (vif.mon_cb.psel && vif.mon_cb.penable && vif.mon_cb.pready));

        tr = apb_txn::type_id::create("tr");
        tr.addr  = vif.mon_cb.paddr;
        tr.write = vif.mon_cb.pwrite;
        tr.data  = vif.mon_cb.pwrite ? vif.mon_cb.pwdata : vif.mon_cb.prdata;

        ap.write(tr);

        `uvm_info(get_type_name(), {"Collected: ", tr.convert2string()}, UVM_HIGH)
    endtask
endclass
```

### 35.7 Agent

```systemverilog
class apb_agt extends uvm_agent;
    `uvm_component_utils(apb_agt)

    apb_drv                         drv;
    apb_mon                         mon;
    uvm_sequencer #(apb_txn)        sqr;
    uvm_analysis_port #(apb_txn)    ap;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        mon = apb_mon::type_id::create("mon", this);

        if (get_is_active() == UVM_ACTIVE) begin
            drv = apb_drv::type_id::create("drv", this);
            sqr = uvm_sequencer #(apb_txn)::type_id::create("sqr", this);
        end
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        ap = mon.ap;
        if (get_is_active() == UVM_ACTIVE)
            drv.seq_item_port.connect(sqr.seq_item_export);
    endfunction
endclass
```

### 35.8 Scoreboard

```systemverilog
class apb_sb extends uvm_scoreboard;
    `uvm_component_utils(apb_sb)

    uvm_analysis_imp #(apb_txn, apb_sb) imp;
    bit [31:0] ref_mem[bit [7:0]];
    int pass_count, fail_count;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        imp = new("imp", this);
    endfunction

    virtual function void write(apb_txn tr);
        if (tr.write) begin
            ref_mem[tr.addr] = tr.data;
            `uvm_info(get_type_name(), $sformatf(
                "REF WRITE: [0x%02h] = 0x%08h", tr.addr, tr.data), UVM_HIGH)
        end else begin
            if (ref_mem.exists(tr.addr)) begin
                if (tr.data === ref_mem[tr.addr]) begin
                    pass_count++;
                    `uvm_info(get_type_name(), $sformatf(
                        "PASS: [0x%02h] = 0x%08h", tr.addr, tr.data), UVM_MEDIUM)
                end else begin
                    fail_count++;
                    `uvm_error(get_type_name(), $sformatf(
                        "FAIL: [0x%02h] exp=0x%08h got=0x%08h",
                        tr.addr, ref_mem[tr.addr], tr.data))
                end
            end else begin
                `uvm_warning(get_type_name(), $sformatf(
                    "Read from unwritten address 0x%02h", tr.addr))
            end
        end
    endfunction

    virtual function void report_phase(uvm_phase phase);
        `uvm_info(get_type_name(), $sformatf(
            "\n========== SCOREBOARD ==========\n  PASS: %0d\n  FAIL: %0d\n================================",
            pass_count, fail_count), UVM_LOW)
    endfunction
endclass
```

### 35.9 Environment

```systemverilog
class apb_env_top extends uvm_env;
    `uvm_component_utils(apb_env_top)

    apb_agt agt;
    apb_sb  sb;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        agt = apb_agt::type_id::create("agt", this);
        sb  = apb_sb::type_id::create("sb", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        agt.ap.connect(sb.imp);
    endfunction
endclass
```

### 35.10 Test

```systemverilog
class apb_base_test extends uvm_test;
    `uvm_component_utils(apb_base_test)

    apb_env_top env;

    function new(string name = "apb_base_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = apb_env_top::type_id::create("env", this);
    endfunction

    virtual function void end_of_elaboration_phase(uvm_phase phase);
        uvm_top.print_topology();
    endfunction

    virtual function void report_phase(uvm_phase phase);
        uvm_report_server svr = uvm_report_server::get_server();
        if (svr.get_severity_count(UVM_ERROR) == 0 &&
            svr.get_severity_count(UVM_FATAL) == 0)
            `uvm_info(get_type_name(), "\n*** TEST PASSED ***", UVM_NONE)
        else
            `uvm_info(get_type_name(), "\n*** TEST FAILED ***", UVM_NONE)
    endfunction
endclass

class apb_wr_rd_test extends apb_base_test;
    `uvm_component_utils(apb_wr_rd_test)

    function new(string name = "apb_wr_rd_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual task run_phase(uvm_phase phase);
        apb_wr_rd_seq seq;

        phase.raise_objection(this, "Starting write-read test");

        seq = apb_wr_rd_seq::type_id::create("seq");
        seq.num_pairs = 20;
        seq.start(env.agt.sqr);

        #100;
        phase.drop_objection(this, "Write-read test complete");
    endtask
endclass
```

### 35.11 Top-Level Module

```systemverilog
module tb_top;
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    // All testbench files
    `include "apb_txn.sv"
    `include "apb_write_seq.sv"
    `include "apb_read_seq.sv"
    `include "apb_wr_rd_seq.sv"
    `include "apb_drv.sv"
    `include "apb_mon.sv"
    `include "apb_agt.sv"
    `include "apb_sb.sv"
    `include "apb_env_top.sv"
    `include "apb_base_test.sv"
    `include "apb_wr_rd_test.sv"

    logic clk;
    apb_if apb_bus(clk);

    // DUT
    apb_memory #(.ADDR_WIDTH(8), .DATA_WIDTH(32)) dut (
        .pclk     (clk),
        .preset_n (apb_bus.preset_n),
        .psel     (apb_bus.psel),
        .penable  (apb_bus.penable),
        .pwrite   (apb_bus.pwrite),
        .paddr    (apb_bus.paddr),
        .pwdata   (apb_bus.pwdata),
        .prdata   (apb_bus.prdata),
        .pready   (apb_bus.pready),
        .pslverr  (apb_bus.pslverr)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Reset
    initial begin
        apb_bus.preset_n = 0;
        #20;
        apb_bus.preset_n = 1;
    end

    // UVM entry
    initial begin
        uvm_config_db #(virtual apb_if)::set(null, "*.agt.*", "vif", apb_bus);
        run_test();
    end

    // Waveform dump
    initial begin
        $dumpfile("apb_tb.vcd");
        $dumpvars(0, tb_top);
    end
endmodule
```

---

## Quick Reference — UVM Macro Cheat Sheet

| Macro | Used In | Purpose |
|-------|---------|---------|
| `` `uvm_object_utils(T) `` | `uvm_object` subclasses | Factory + type registration |
| `` `uvm_component_utils(T) `` | `uvm_component` subclasses | Factory + type registration |
| `` `uvm_object_utils_begin(T) / _end `` | With field macros | Factory + field automation |
| `` `uvm_component_utils_begin(T) / _end `` | With field macros | Factory + field automation |
| `` `uvm_info(ID, MSG, VERB) `` | Anywhere | Info message |
| `` `uvm_warning(ID, MSG) `` | Anywhere | Warning message |
| `` `uvm_error(ID, MSG) `` | Anywhere | Error message |
| `` `uvm_fatal(ID, MSG) `` | Anywhere | Fatal — simulation stops |
| `` `uvm_do(SEQ_OR_ITEM) `` | Inside sequence `body()` | Create, randomize, send |
| `` `uvm_do_with(ITEM, CONSTRAINTS) `` | Inside sequence `body()` | Create, randomize with, send |
| `` `uvm_create(ITEM) `` | Inside sequence `body()` | Factory create only |
| `` `uvm_send(ITEM) `` | Inside sequence `body()` | Send (no randomize) |
| `` `uvm_analysis_imp_decl(_SUFFIX) `` | Scoreboards | Multiple write() ports |

---

## Quick Reference — Common `+UVM` Runtime Flags

| Flag | Purpose |
|------|---------|
| `+UVM_TESTNAME=<test>` | Select which test to run |
| `+UVM_VERBOSITY=<level>` | Set global verbosity |
| `+UVM_TIMEOUT=<ns>,YES` | Set simulation timeout |
| `+UVM_MAX_QUIT_COUNT=<n>,YES` | Stop after N errors |
| `+UVM_CONFIG_DB_TRACE` | Trace all config_db operations |
| `+UVM_OBJECTION_TRACE` | Trace all objection activity |
| `+UVM_PHASE_TRACE` | Trace phase transitions |
| `+UVM_DUMP_CMDLINE_ARGS` | Print command-line arguments |

---

## Glossary

| Term | Definition |
|------|-----------|
| **CRV** | Constrained-Random Verification — stimulus is randomly generated within constraints |
| **DUT** | Design Under Test — the RTL being verified |
| **TLM** | Transaction-Level Modeling — communication abstraction for components |
| **RAL** | Register Abstraction Layer — high-level register access model |
| **VIP** | Verification IP — reusable pre-built verification agents |
| **Objection** | Mechanism to prevent a phase from ending while work remains |
| **Factory** | Design pattern allowing runtime class substitution |
| **Sequence** | Ordered stream of transactions sent to a driver via sequencer |
| **Handle** | A pointer/reference to a class object in SystemVerilog |
| **Virtual method** | A method resolved at runtime (dynamic dispatch) |
| **Phase** | A stage in UVM simulation lifecycle (build, connect, run, etc.) |
