# SystemVerilog Classes and UVM: A Comprehensive Tutorial

A deep-dive tutorial covering object-oriented programming in SystemVerilog and how classes power the Universal Verification Methodology (UVM). Every concept is paired with working code examples.

---

## Table of Contents

### Part 1 — SystemVerilog Classes

1. [Introduction to OOP in SystemVerilog](#1-introduction-to-oop-in-systemverilog)
2. [Class Basics](#2-class-basics)
3. [The Constructor — `new()`](#3-the-constructor--new)
4. [Object Handles and `null`](#4-object-handles-and-null)
5. [Encapsulation — `local` and `protected`](#5-encapsulation--local-and-protected)
6. [`this` Keyword](#6-this-keyword)
7. [Static Members](#7-static-members)
8. [Inheritance](#8-inheritance)
9. [Polymorphism and Virtual Methods](#9-polymorphism-and-virtual-methods)
10. [Abstract Classes and Pure Virtual Methods](#10-abstract-classes-and-pure-virtual-methods)
11. [Parameterized (Generic) Classes](#11-parameterized-generic-classes)
12. [Shallow Copy vs. Deep Copy](#12-shallow-copy-vs-deep-copy)
13. [Class Scope Resolution Operator `::`](#13-class-scope-resolution-operator-)
14. [Forward Declarations and Typedef](#14-forward-declarations-and-typedef)
15. [Randomization in Classes](#15-randomization-in-classes)
16. [Interfaces in Classes and Virtual Interfaces](#16-interfaces-in-classes-and-virtual-interfaces)

### Part 2 — UVM Class Architecture

17. [UVM Overview and Philosophy](#17-uvm-overview-and-philosophy)
18. [UVM Class Hierarchy](#18-uvm-class-hierarchy)
19. [`uvm_void` and `uvm_object`](#19-uvm_void-and-uvm_object)
20. [`uvm_object` Core Methods (copy, clone, compare, print, pack/unpack)](#20-uvm_object-core-methods)
21. [`uvm_component` — The Backbone of the Testbench](#21-uvm_component--the-backbone-of-the-testbench)
22. [UVM Phases In Depth](#22-uvm-phases-in-depth)
23. [`uvm_transaction` and `uvm_sequence_item`](#23-uvm_transaction-and-uvm_sequence_item)
24. [`uvm_sequence`](#24-uvm_sequence)
25. [`uvm_driver`](#25-uvm_driver)
26. [`uvm_monitor`](#26-uvm_monitor)
27. [`uvm_agent`](#27-uvm_agent)
28. [`uvm_scoreboard`](#28-uvm_scoreboard)
29. [`uvm_env`](#29-uvm_env)
30. [`uvm_test`](#30-uvm_test)
31. [UVM Factory — Create, Override, Substitute](#31-uvm-factory--create-override-substitute)
32. [UVM Configuration Database (`uvm_config_db`)](#32-uvm-configuration-database-uvm_config_db)
33. [UVM TLM (Transaction-Level Modeling)](#33-uvm-tlm-transaction-level-modeling)
34. [Field Macros and Automation](#34-field-macros-and-automation)
35. [UVM Reporting and Messaging](#35-uvm-reporting-and-messaging)
36. [UVM Register Layer (`uvm_reg`)](#36-uvm-register-layer-uvm_reg)
37. [Putting It All Together — Full UVM Testbench Example](#37-putting-it-all-together--full-uvm-testbench-example)

---

## Part 1 — SystemVerilog Classes

---

### 1. Introduction to OOP in SystemVerilog

SystemVerilog extends Verilog with a full object-oriented programming (OOP) model. Classes provide encapsulation, inheritance, and polymorphism — the three pillars of OOP — enabling reusable, modular verification environments.

**Why classes matter for verification:**

- **Encapsulation** — bundle data and operations into self-contained objects.
- **Inheritance** — extend existing classes without modifying them.
- **Polymorphism** — write generic code that works with any derived type.
- **Randomization** — constrained-random generation is built into the class system.
- **Reuse** — UVM is entirely built on SystemVerilog classes.

Classes exist only in simulation (the "verification" side). They cannot be synthesized.

---

### 2. Class Basics

A class defines a data type containing **properties** (variables) and **methods** (functions/tasks).

```systemverilog
class Packet;
    // Properties
    bit [7:0]  src_addr;
    bit [7:0]  dst_addr;
    bit [31:0] payload;
    bit [15:0] crc;

    // Method
    function bit [15:0] compute_crc();
        compute_crc = src_addr ^ dst_addr ^ payload[15:0] ^ payload[31:16];
    endfunction

    function void display();
        $display("Packet: src=%0h dst=%0h payload=%0h crc=%0h",
                 src_addr, dst_addr, payload, crc);
    endfunction
endclass
```

**Creating objects:**

```systemverilog
module tb;
    initial begin
        Packet pkt;          // Declare a handle (initially null)
        pkt = new();         // Allocate the object
        pkt.src_addr = 8'hA0;
        pkt.dst_addr = 8'hB1;
        pkt.payload  = 32'hDEAD_BEEF;
        pkt.crc      = pkt.compute_crc();
        pkt.display();
    end
endmodule
```

Key observations:

- `Packet pkt` declares a **handle** — a typed pointer. It does not create an object.
- `pkt = new()` constructs the object and assigns its handle.
- Members are accessed with the `.` operator.

---

### 3. The Constructor — `new()`

Every class has an implicit default constructor. You can define an explicit one:

```systemverilog
class Packet;
    bit [7:0]  src_addr;
    bit [7:0]  dst_addr;
    bit [31:0] payload;

    function new(bit [7:0] src = 0, bit [7:0] dst = 0);
        this.src_addr = src;
        this.dst_addr = dst;
        this.payload  = 0;
    endfunction
endclass

// Usage
Packet p1 = new();                // src=0, dst=0
Packet p2 = new(8'hAA, 8'hBB);   // src=AA, dst=BB
```

Rules for constructors:

| Rule | Detail |
|------|--------|
| Return type | Always `function new` — no explicit return type keyword |
| Void return | Constructors cannot return a value |
| One per class | Only one `new()` per class (no overloading) |
| Inheritance | Must call `super.new()` if parent has a non-default constructor |

---

### 4. Object Handles and `null`

Handles are similar to pointers in C/C++. They reference heap-allocated objects.

```systemverilog
class Transaction;
    int data;
    function new(int d);
        this.data = d;
    endfunction
endclass

module tb;
    initial begin
        Transaction t1, t2;

        t1 = new(42);
        t2 = t1;          // t2 now points to the SAME object as t1

        t2.data = 99;
        $display("t1.data = %0d", t1.data); // Prints 99 — same object

        t1 = null;         // t1 no longer references the object
        // t2 still references it; the object is NOT garbage-collected yet

        t2 = null;         // Now the object has zero references — eligible for GC
    end
endmodule
```

**Handle comparison:**

```systemverilog
if (t1 == t2)       // True if both point to the same object
if (t1 == null)      // True if t1 does not reference any object
if (t1 != null)      // True if t1 references an object
```

---

### 5. Encapsulation — `local` and `protected`

SystemVerilog provides two access modifiers (there is no `public` keyword; members are public by default).

```systemverilog
class SecurePacket;
    local    bit [7:0] encryption_key;  // Accessible ONLY inside this class
    protected bit [7:0] internal_id;    // Accessible in this class and subclasses
    bit [7:0] payload;                  // Public — accessible everywhere

    function new(bit [7:0] key, bit [7:0] id);
        this.encryption_key = key;
        this.internal_id    = id;
    endfunction

    function bit [7:0] get_encrypted_payload();
        return payload ^ encryption_key;
    endfunction
endclass

class SpecialPacket extends SecurePacket;
    function void show();
        // $display(encryption_key);  // COMPILE ERROR — local to parent
        $display("id = %0h", internal_id);  // OK — protected is accessible
    endfunction
endclass
```

| Keyword | Accessible in same class | Accessible in subclass | Accessible externally |
|---------|------------------------|----------------------|---------------------|
| *(default — public)* | Yes | Yes | Yes |
| `protected` | Yes | Yes | No |
| `local` | Yes | No | No |

---

### 6. `this` Keyword

`this` refers to the current object instance, disambiguating between class members and local variables with the same name.

```systemverilog
class Register;
    string name;
    int    value;

    function new(string name, int value);
        this.name  = name;    // this.name = member; name = parameter
        this.value = value;
    endfunction

    function void set(int value);
        this.value = value;
    endfunction
endclass
```

---

### 7. Static Members

Static properties and methods belong to the **class**, not to any instance.

```systemverilog
class Packet;
    static int packet_count = 0;   // Shared across all Packet objects
    int        id;

    function new();
        packet_count++;
        id = packet_count;
    endfunction

    static function int get_count();
        return packet_count;
    endfunction

    static function void reset_count();
        packet_count = 0;
    endfunction
endclass

module tb;
    initial begin
        Packet p1 = new();
        Packet p2 = new();
        Packet p3 = new();
        $display("Total packets: %0d", Packet::get_count()); // 3
    end
endmodule
```

Rules for static methods:

- Cannot access non-static members (no implicit `this`).
- Called via `ClassName::method()` or through an object handle.

---

### 8. Inheritance

Inheritance lets a derived class reuse and extend a base class.

```systemverilog
class Transaction;
    bit [31:0] addr;
    bit [31:0] data;

    function new(bit [31:0] addr = 0, bit [31:0] data = 0);
        this.addr = addr;
        this.data = data;
    endfunction

    function void display();
        $display("[Transaction] addr=%0h data=%0h", addr, data);
    endfunction
endclass

class WriteTransaction extends Transaction;
    bit [3:0] byte_enable;

    function new(bit [31:0] addr = 0, bit [31:0] data = 0, bit [3:0] be = 4'hF);
        super.new(addr, data);       // Must call parent constructor
        this.byte_enable = be;
    endfunction

    function void display();         // Overrides parent's display()
        $display("[WriteTransaction] addr=%0h data=%0h be=%04b",
                 addr, data, byte_enable);
    endfunction
endclass

class ReadTransaction extends Transaction;
    int latency;

    function new(bit [31:0] addr = 0);
        super.new(addr, 0);
        this.latency = 0;
    endfunction
endclass
```

**Key rules:**

- `extends` specifies the parent class.
- `super.new(...)` calls the parent constructor and must be the **first statement** in the child constructor.
- If the parent has a default constructor, `super.new()` is called implicitly.
- SystemVerilog supports **single inheritance only** — each class has at most one parent.

---

### 9. Polymorphism and Virtual Methods

Polymorphism allows a base-class handle to refer to a derived-class object and invoke the correct method at runtime.

**Without `virtual` — static dispatch (WRONG behavior for polymorphism):**

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

module tb;
    initial begin
        Animal a;
        Dog d = new();
        a = d;             // Base handle, derived object
        a.speak();          // Prints "..." — calls Animal::speak (static dispatch)
    end
endmodule
```

**With `virtual` — dynamic dispatch (CORRECT polymorphism):**

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

class Cat extends Animal;
    virtual function void speak();
        $display("Meow!");
    endfunction
endclass

module tb;
    initial begin
        Animal animals[3];
        animals[0] = new();           // Animal
        animals[1] = Dog::new();      // Dog
        animals[2] = Cat::new();      // Cat

        foreach (animals[i])
            animals[i].speak();       // Calls the correct method for each type
        // Output:
        //   ...
        //   Woof!
        //   Meow!
    end
endmodule
```

**Guideline:** Always declare methods as `virtual` if you expect them to be overridden. UVM uses `virtual` extensively.

---

### 10. Abstract Classes and Pure Virtual Methods

An abstract class cannot be instantiated — it defines an interface that subclasses must implement.

```systemverilog
virtual class Driver;
    pure virtual task send(input bit [31:0] data);
    pure virtual function string get_name();

    function void log(string msg);
        $display("[%s] %s", get_name(), msg);
    endfunction
endclass

class APBDriver extends Driver;
    virtual task send(input bit [31:0] data);
        log($sformatf("Driving APB data: %0h", data));
        #10;
    endtask

    virtual function string get_name();
        return "APBDriver";
    endfunction
endclass

class AXIDriver extends Driver;
    virtual task send(input bit [31:0] data);
        log($sformatf("Driving AXI data: %0h", data));
        #5;
    endtask

    virtual function string get_name();
        return "AXIDriver";
    endfunction
endclass
```

| Concept | Syntax | Rule |
|---------|--------|------|
| Abstract class | `virtual class Foo;` | Cannot be instantiated |
| Pure virtual method | `pure virtual function ...;` | No body; must be overridden |
| Concrete class | Regular class extending abstract class | Must implement all pure virtual methods |

---

### 11. Parameterized (Generic) Classes

Parameterized classes are SystemVerilog's equivalent of C++ templates.

```systemverilog
class Stack #(type T = int, int DEPTH = 16);
    T    storage[DEPTH];
    int  sp;

    function new();
        sp = 0;
    endfunction

    function void push(T item);
        if (sp < DEPTH) begin
            storage[sp] = item;
            sp++;
        end else
            $error("Stack overflow");
    endfunction

    function T pop();
        if (sp > 0) begin
            sp--;
            return storage[sp];
        end else begin
            $error("Stack underflow");
            return T'(0);
        end
    endfunction

    function bit is_empty();
        return (sp == 0);
    endfunction

    function int size();
        return sp;
    endfunction
endclass

module tb;
    initial begin
        Stack #(bit [7:0], 8)  byte_stack  = new();
        Stack #(string,    32) str_stack   = new();

        byte_stack.push(8'hAB);
        byte_stack.push(8'hCD);
        $display("Popped: %0h", byte_stack.pop()); // CD

        str_stack.push("hello");
        str_stack.push("world");
        $display("Popped: %s", str_stack.pop());    // world
    end
endmodule
```

---

### 12. Shallow Copy vs. Deep Copy

```systemverilog
class Header;
    bit [7:0] src;
    bit [7:0] dst;

    function new(bit [7:0] s = 0, bit [7:0] d = 0);
        src = s;
        dst = d;
    endfunction
endclass

class Packet;
    int      id;
    Header   hdr;   // Handle to another object

    function new(int id, bit [7:0] s, bit [7:0] d);
        this.id  = id;
        this.hdr = new(s, d);
    endfunction

    function Packet deep_copy();
        Packet p  = new(this.id, 0, 0);
        p.hdr     = new(this.hdr.src, this.hdr.dst);  // New Header object
        return p;
    endfunction
endclass

module tb;
    initial begin
        Packet p1, p2, p3;

        p1 = new(1, 8'hAA, 8'hBB);

        // Shallow copy — shares the Header object
        p2 = new p1;
        p2.id = 2;
        p2.hdr.src = 8'hCC;
        $display("p1.hdr.src = %0h", p1.hdr.src); // CC — changed by p2!

        // Deep copy — independent Header object
        p3 = p1.deep_copy();
        p3.id = 3;
        p3.hdr.src = 8'hDD;
        $display("p1.hdr.src = %0h", p1.hdr.src); // CC — unchanged by p3
    end
endmodule
```

| Operation | Syntax | Behavior |
|-----------|--------|----------|
| Handle assignment | `p2 = p1` | Both handles point to the **same** object |
| Shallow copy | `p2 = new p1` | New object, but nested handles are **shared** |
| Deep copy | User-defined method | New object with **independent** copies of nested objects |

---

### 13. Class Scope Resolution Operator `::`

The `::` operator accesses static members, typedefs, and enums defined inside a class.

```systemverilog
class Config;
    typedef enum {IDLE, ACTIVE, ERROR} state_e;
    static int instance_count = 0;

    state_e state;

    function new();
        instance_count++;
        state = IDLE;
    endfunction

    static function int get_instance_count();
        return instance_count;
    endfunction
endclass

module tb;
    initial begin
        Config::state_e current_state;     // Access typedef via ::
        current_state = Config::ACTIVE;    // Access enum literal via ::

        Config c1 = new();
        Config c2 = new();
        $display("Instances: %0d", Config::get_instance_count()); // 2
    end
endmodule
```

---

### 14. Forward Declarations and Typedef

When two classes reference each other, use a forward declaration (typedef) to break the cycle.

```systemverilog
typedef class Response;    // Forward declaration

class Request;
    int id;
    Response rsp;          // Legal because of the forward declaration

    function new(int id);
        this.id = id;
    endfunction
endclass

class Response;
    int    id;
    bit    status;
    Request req;

    function new(int id, bit status);
        this.id     = id;
        this.status = status;
    endfunction

    function void link(Request r);
        this.req = r;
        r.rsp    = this;
    endfunction
endclass
```

---

### 15. Randomization in Classes

SystemVerilog's constrained-random verification is tightly integrated with classes.

```systemverilog
class EthernetFrame;
    rand  bit [47:0] dst_mac;
    rand  bit [47:0] src_mac;
    rand  bit [15:0] ethertype;
    rand  bit [7:0]  payload[];
    randc bit [2:0]  priority;     // Cyclic randomization

    constraint valid_ethertype {
        ethertype inside {16'h0800, 16'h0806, 16'h86DD};
    }

    constraint payload_size {
        payload.size() inside {[46:1500]};
    }

    constraint no_broadcast {
        dst_mac != 48'hFFFF_FFFF_FFFF;
    }

    function void display();
        $display("dst=%012h src=%012h type=%04h len=%0d pri=%0d",
                 dst_mac, src_mac, ethertype, payload.size(), priority);
    endfunction
endclass

module tb;
    initial begin
        EthernetFrame frame = new();

        repeat (5) begin
            if (!frame.randomize())
                $fatal("Randomization failed");
            frame.display();
        end

        // Inline constraint
        if (!frame.randomize() with {
            payload.size() == 64;
            ethertype == 16'h0800;
        })
            $fatal("Randomization failed");
        frame.display();
    end
endmodule
```

**Randomization control:**

```systemverilog
frame.rand_mode(0);                // Disable ALL randomization
frame.payload.rand_mode(0);        // Disable randomization for payload only
frame.valid_ethertype.constraint_mode(0); // Disable specific constraint
```

**`pre_randomize()` and `post_randomize()` callbacks:**

```systemverilog
class Packet;
    rand bit [7:0] data;
    rand bit       parity;

    function void post_randomize();
        parity = ^data;    // Compute parity after randomization
    endfunction
endclass
```

---

### 16. Interfaces in Classes and Virtual Interfaces

Classes cannot directly access interface ports. Instead, use **virtual interfaces** to connect class-based testbench components to RTL signals.

```systemverilog
interface bus_if(input logic clk);
    logic        valid;
    logic        ready;
    logic [31:0] data;

    clocking driver_cb @(posedge clk);
        output valid, data;
        input  ready;
    endclocking

    clocking monitor_cb @(posedge clk);
        input valid, ready, data;
    endclocking
endinterface

class BusDriver;
    virtual bus_if vif;    // Virtual interface handle

    function new(virtual bus_if vif);
        this.vif = vif;
    endfunction

    task drive(bit [31:0] data);
        @(vif.driver_cb);
        vif.driver_cb.valid <= 1;
        vif.driver_cb.data  <= data;
        @(vif.driver_cb);
        wait(vif.driver_cb.ready);
        vif.driver_cb.valid <= 0;
    endtask
endclass

module tb;
    logic clk = 0;
    always #5 clk = ~clk;

    bus_if bif(clk);

    initial begin
        BusDriver drv = new(bif);
        drv.drive(32'hCAFE_BABE);
        $finish;
    end
endmodule
```

---

## Part 2 — UVM Class Architecture

---

### 17. UVM Overview and Philosophy

The Universal Verification Methodology (UVM) is an industry-standard SystemVerilog class library for building reusable, scalable verification environments. Its core design principles are:

| Principle | Mechanism |
|-----------|-----------|
| **Separation of concerns** | Stimulus generation, driving, monitoring, and checking are handled by dedicated components |
| **Reuse** | Components are configured — not modified — for different DUTs via the factory and config_db |
| **Scalability** | Hierarchical component tree mirrors the DUT hierarchy |
| **Automation** | Factory pattern, phasing, field macros, and TLM connections reduce boilerplate |

All UVM classes inherit from two root classes: `uvm_object` (data/transactions) and `uvm_component` (structural testbench elements).

---

### 18. UVM Class Hierarchy

```
uvm_void
├── uvm_object
│   ├── uvm_transaction
│   │   └── uvm_sequence_item
│   ├── uvm_sequence
│   ├── uvm_reg_item
│   ├── uvm_reg_map
│   ├── uvm_reg_block
│   ├── uvm_reg
│   ├── uvm_reg_field
│   └── uvm_event
├── uvm_component
│   ├── uvm_test
│   ├── uvm_env
│   ├── uvm_agent
│   ├── uvm_driver
│   ├── uvm_monitor
│   ├── uvm_sequencer
│   ├── uvm_scoreboard
│   └── uvm_subscriber
└── uvm_port_base (TLM)
    ├── uvm_analysis_port
    ├── uvm_analysis_export
    └── uvm_tlm_fifo
```

**Key distinction:**

- **`uvm_object`** — data objects with a finite lifespan (transactions, sequences, register descriptors). They do *not* participate in the phase mechanism.
- **`uvm_component`** — persistent structural elements built during `build_phase` and alive for the entire simulation. They *do* participate in phases.

---

### 19. `uvm_void` and `uvm_object`

#### `uvm_void`

`uvm_void` is the ultimate root of all UVM classes. It is completely empty — no methods, no properties. Its sole purpose is to provide a common base type so that any UVM class can be stored in a generic container.

#### `uvm_object`

`uvm_object` extends `uvm_void` and provides the foundation for all data-centric UVM classes. It defines identity, comparison, printing, packing, and the factory interface.

**Essential internal methods:**

| Method | Signature | Purpose |
|--------|-----------|---------|
| `get_name()` | `function string get_name()` | Returns the instance name |
| `get_full_name()` | `function string get_full_name()` | Returns full hierarchical name |
| `get_type_name()` | `function string get_type_name()` | Returns the class type name (used by factory) |
| `create()` | `function uvm_object create(string name = "")` | Factory creation — returns a new object of the correct (possibly overridden) type |
| `clone()` | `function uvm_object clone()` | Creates a new object via `create()` and then `copy()` |
| `copy()` | `function void copy(uvm_object rhs)` | Copies data from `rhs` into `this` |
| `compare()` | `function bit compare(uvm_object rhs, uvm_comparer comparer = null)` | Deep comparison; returns 1 if equal |
| `print()` | `function void print(uvm_printer printer = null)` | Pretty-prints the object |
| `sprint()` | `function string sprint(uvm_printer printer = null)` | Returns a string representation |
| `record()` | `function void record(uvm_recorder recorder = null)` | Records object to a transaction database |
| `pack()` / `unpack()` | `function int pack(ref bit bitstream[], ...)` | Serializes/deserializes fields to/from a bit vector |
| `do_copy()` | `virtual function void do_copy(uvm_object rhs)` | User override hook for custom copy logic |
| `do_compare()` | `virtual function bit do_compare(uvm_object rhs, uvm_comparer comparer)` | User override hook for custom comparison |
| `do_print()` | `virtual function void do_print(uvm_printer printer)` | User override hook for custom printing |
| `do_pack()` | `virtual function void do_pack(uvm_packer packer)` | User override hook for custom packing |
| `do_unpack()` | `virtual function void do_unpack(uvm_packer packer)` | User override hook for custom unpacking |

**Design pattern:** The public methods (`copy`, `compare`, `print`, `pack`, `unpack`) call the corresponding `do_*` virtual hooks. You override the `do_*` methods to customize behavior while the framework handles boilerplate (null checks, type checks, field-macro automation).

---

### 20. `uvm_object` Core Methods

#### 20.1 — `copy()` and `do_copy()`

```systemverilog
class my_transaction extends uvm_sequence_item;
    `uvm_object_utils(my_transaction)

    rand bit [31:0] addr;
    rand bit [31:0] data;
    rand bit [3:0]  strobe;

    function new(string name = "my_transaction");
        super.new(name);
    endfunction

    virtual function void do_copy(uvm_object rhs);
        my_transaction rhs_;
        super.do_copy(rhs);
        if (!$cast(rhs_, rhs))
            `uvm_fatal("COPY", "Cast failed in do_copy")
        this.addr   = rhs_.addr;
        this.data   = rhs_.data;
        this.strobe = rhs_.strobe;
    endfunction
endclass
```

**Usage:**

```systemverilog
my_transaction t1, t2;
t1 = my_transaction::type_id::create("t1");
t2 = my_transaction::type_id::create("t2");
t1.randomize();
t2.copy(t1);   // t2 now has the same field values as t1
```

#### 20.2 — `clone()`

`clone()` = `create()` + `copy()`. Returns a `uvm_object` handle, so you must cast:

```systemverilog
uvm_object obj;
my_transaction t1, t2;

t1 = my_transaction::type_id::create("t1");
t1.randomize();

obj = t1.clone();
if (!$cast(t2, obj))
    `uvm_fatal("CLONE", "Cast failed")

// t2 is now an independent deep copy of t1
```

#### 20.3 — `compare()` and `do_compare()`

```systemverilog
virtual function bit do_compare(uvm_object rhs, uvm_comparer comparer);
    my_transaction rhs_;
    bit status;

    status = super.do_compare(rhs, comparer);
    if (!$cast(rhs_, rhs))
        return 0;

    status &= (this.addr   == rhs_.addr);
    status &= (this.data   == rhs_.data);
    status &= (this.strobe == rhs_.strobe);
    return status;
endfunction
```

**Usage:**

```systemverilog
if (!t1.compare(t2))
    `uvm_error("CMP", "Transactions do not match")
```

#### 20.4 — `print()` and `do_print()`

```systemverilog
virtual function void do_print(uvm_printer printer);
    super.do_print(printer);
    printer.print_field_int("addr",   addr,   32, UVM_HEX);
    printer.print_field_int("data",   data,   32, UVM_HEX);
    printer.print_field_int("strobe", strobe,  4, UVM_BIN);
endfunction
```

**Usage:**

```systemverilog
t1.print();        // Uses default table printer
t1.print(uvm_default_line_printer);  // One-line format
```

#### 20.5 — `pack()` / `unpack()` and `do_pack()` / `do_unpack()`

```systemverilog
virtual function void do_pack(uvm_packer packer);
    super.do_pack(packer);
    packer.pack_field_int(addr,   32);
    packer.pack_field_int(data,   32);
    packer.pack_field_int(strobe,  4);
endfunction

virtual function void do_unpack(uvm_packer packer);
    super.do_unpack(packer);
    addr   = packer.unpack_field_int(32);
    data   = packer.unpack_field_int(32);
    strobe = packer.unpack_field_int(4);
endfunction
```

**Usage:**

```systemverilog
bit bitstream[];
int num_bits;

num_bits = t1.pack(bitstream);
$display("Packed %0d bits", num_bits);

my_transaction t3 = my_transaction::type_id::create("t3");
t3.unpack(bitstream);
```

#### 20.6 — `convert2string()`

A convenience method to return a one-line string representation:

```systemverilog
virtual function string convert2string();
    return $sformatf("addr=%0h data=%0h strobe=%04b", addr, data, strobe);
endfunction
```

---

### 21. `uvm_component` — The Backbone of the Testbench

`uvm_component` extends `uvm_object` and adds:

| Feature | Methods / Concepts |
|---------|--------------------|
| **Parent-child hierarchy** | `get_parent()`, `get_children()`, `get_full_name()` |
| **Phase callbacks** | `build_phase`, `connect_phase`, `run_phase`, etc. |
| **Factory registration** | `uvm_component_utils` macro |
| **Configuration** | `uvm_config_db#(T)::set/get` |
| **Objection mechanism** | `phase.raise_objection()` / `phase.drop_objection()` |

**Every `uvm_component` has a name and a parent**, forming a tree:

```
uvm_test_top (uvm_test)
└── env (uvm_env)
    ├── agent (uvm_agent)
    │   ├── driver (uvm_driver)
    │   ├── sequencer (uvm_sequencer)
    │   └── monitor (uvm_monitor)
    └── scoreboard (uvm_scoreboard)
```

**Key internal methods:**

```systemverilog
// Hierarchy
function uvm_component get_parent();
function void          get_children(ref uvm_component children[$]);
function string        get_full_name();   // e.g. "uvm_test_top.env.agent.driver"
function uvm_component lookup(string name);

// Phase callbacks (virtual — override in subclass)
virtual function void build_phase(uvm_phase phase);
virtual function void connect_phase(uvm_phase phase);
virtual function void end_of_elaboration_phase(uvm_phase phase);
virtual function void start_of_simulation_phase(uvm_phase phase);
virtual task          run_phase(uvm_phase phase);
virtual function void extract_phase(uvm_phase phase);
virtual function void check_phase(uvm_phase phase);
virtual function void report_phase(uvm_phase phase);
virtual function void final_phase(uvm_phase phase);
```

---

### 22. UVM Phases In Depth

UVM defines a standard simulation lifecycle broken into phases. Phases execute in a specific order and are either **functions** (execute in zero simulation time) or **tasks** (consume simulation time).

```
                    ┌─────────────────┐
                    │   build_phase   │ ← Top-down, zero time
                    └────────┬────────┘
                    ┌────────▼────────┐
                    │ connect_phase   │ ← Bottom-up, zero time
                    └────────┬────────┘
                    ┌────────▼────────┐
                    │end_of_elaboration│ ← Bottom-up, zero time
                    └────────┬────────┘
                    ┌────────▼────────┐
                    │start_of_simulation│ ← Bottom-up, zero time
                    └────────┬────────┘
                    ┌────────▼────────┐
                    │   run_phase     │ ← All components in parallel, consumes time
                    │   (+ sub-phases:│
                    │    reset, configure,│
                    │    main, shutdown)│
                    └────────┬────────┘
                    ┌────────▼────────┐
                    │  extract_phase  │ ← Bottom-up, zero time
                    └────────┬────────┘
                    ┌────────▼────────┐
                    │   check_phase   │ ← Bottom-up, zero time
                    └────────┬────────┘
                    ┌────────▼────────┐
                    │  report_phase   │ ← Bottom-up, zero time
                    └────────┬────────┘
                    ┌────────▼────────┐
                    │   final_phase   │ ← Top-down, zero time
                    └────────┬────────┘
                             ▼
                        Simulation End
```

**Phase details:**

| Phase | Direction | Time | Typical Use |
|-------|-----------|------|-------------|
| `build_phase` | Top-down | Zero | Construct children, apply config |
| `connect_phase` | Bottom-up | Zero | Connect TLM ports, assign virtual interfaces |
| `end_of_elaboration_phase` | Bottom-up | Zero | Print topology, final config checks |
| `start_of_simulation_phase` | Bottom-up | Zero | Print banners, open files |
| `run_phase` | Parallel | Consumes time | Active stimulus, driving, monitoring |
| `extract_phase` | Bottom-up | Zero | Collect results from DUT |
| `check_phase` | Bottom-up | Zero | Compare expected vs actual |
| `report_phase` | Bottom-up | Zero | Print pass/fail summary |
| `final_phase` | Top-down | Zero | Close files, cleanup |

**Objection mechanism** controls when `run_phase` ends:

```systemverilog
virtual task run_phase(uvm_phase phase);
    phase.raise_objection(this);    // "I have work to do"
    // ... stimulus ...
    phase.drop_objection(this);     // "I'm done" — phase ends when all objections dropped
endtask
```

---

### 23. `uvm_transaction` and `uvm_sequence_item`

#### `uvm_transaction`

`uvm_transaction` extends `uvm_object` and adds timing information:

| Method | Purpose |
|--------|---------|
| `accept_tr()` | Record that transaction was accepted |
| `begin_tr()` | Mark transaction start time |
| `end_tr()` | Mark transaction end time |
| `get_begin_time()` | Query start timestamp |
| `get_end_time()` | Query end timestamp |

#### `uvm_sequence_item`

`uvm_sequence_item` extends `uvm_transaction` and adds the sequencer linkage needed for the sequence-driver handshake:

| Method | Purpose |
|--------|---------|
| `get_sequencer()` | Returns the sequencer this item is executing on |
| `get_parent_sequence()` | Returns the parent sequence |
| `set_sequencer()` | Assigns the sequencer |
| `set_item_context()` | Sets parent sequence and sequencer |

**This is the class you should extend for your transaction types:**

```systemverilog
class apb_transaction extends uvm_sequence_item;
    `uvm_object_utils(apb_transaction)

    rand bit [31:0] addr;
    rand bit [31:0] data;
    rand bit        write;

    constraint addr_align {
        addr[1:0] == 2'b00;  // Word-aligned
    }

    constraint addr_range {
        addr inside {[32'h0000_0000 : 32'h0000_FFFF]};
    }

    function new(string name = "apb_transaction");
        super.new(name);
    endfunction

    virtual function string convert2string();
        return $sformatf("%s addr=0x%08h data=0x%08h",
                         write ? "WR" : "RD", addr, data);
    endfunction

    virtual function void do_copy(uvm_object rhs);
        apb_transaction rhs_;
        super.do_copy(rhs);
        $cast(rhs_, rhs);
        this.addr  = rhs_.addr;
        this.data  = rhs_.data;
        this.write = rhs_.write;
    endfunction

    virtual function bit do_compare(uvm_object rhs, uvm_comparer comparer);
        apb_transaction rhs_;
        if (!$cast(rhs_, rhs)) return 0;
        return (super.do_compare(rhs, comparer) &&
                this.addr  == rhs_.addr &&
                this.data  == rhs_.data &&
                this.write == rhs_.write);
    endfunction

    virtual function void do_print(uvm_printer printer);
        super.do_print(printer);
        printer.print_field_int("addr",  addr,  32, UVM_HEX);
        printer.print_field_int("data",  data,  32, UVM_HEX);
        printer.print_field_int("write", write,  1, UVM_BIN);
    endfunction
endclass
```

---

### 24. `uvm_sequence`

A `uvm_sequence` generates a stream of `uvm_sequence_item` objects and sends them to a sequencer/driver.

**Internal methods and flow:**

| Method | Purpose |
|--------|---------|
| `body()` | The main task — override this to generate items |
| `start()` | Starts the sequence on a sequencer |
| `start_item()` | Request arbitration grant from sequencer |
| `finish_item()` | Send the item to the driver and wait for completion |
| `get_response()` | Retrieve driver's response (optional) |
| `pre_body()` | Hook called before `body()` |
| `post_body()` | Hook called after `body()` |
| `pre_start()` | Hook called before the sequence is started |
| `post_start()` | Hook called after the sequence finishes |
| `mid_do()` | Hook called between `start_item()` and `finish_item()` |
| `pre_do()` | Hook called inside `start_item()` before grant |
| `post_do()` | Hook called after `finish_item()` completes |

**Sequence-driver handshake flow:**

```
Sequence                          Sequencer                    Driver
   │                                  │                          │
   ├─── start_item(item) ──────────►  │                          │
   │    [waits for arbitration grant]  │                          │
   │                                  │  ◄──── get_next_item() ──┤
   │  ◄── grant ──────────────────────┤                          │
   │                                  │                          │
   │    [randomize item]              │                          │
   │                                  │                          │
   ├─── finish_item(item) ─────────►  │ ─── deliver item ──────► │
   │                                  │                          │
   │    [wait for driver to finish]   │  ◄──── item_done() ──────┤
   │  ◄── return ─────────────────────┤                          │
```

**Example sequence:**

```systemverilog
class apb_write_seq extends uvm_sequence #(apb_transaction);
    `uvm_object_utils(apb_write_seq)

    rand int unsigned num_writes;

    constraint default_writes {
        num_writes inside {[1:20]};
    }

    function new(string name = "apb_write_seq");
        super.new(name);
    endfunction

    virtual task body();
        apb_transaction txn;

        repeat (num_writes) begin
            txn = apb_transaction::type_id::create("txn");
            start_item(txn);
            if (!txn.randomize() with { write == 1; })
                `uvm_fatal("SEQ", "Randomization failed")
            finish_item(txn);
            `uvm_info("SEQ", txn.convert2string(), UVM_MEDIUM)
        end
    endtask
endclass
```

**Sequence of sequences (virtual sequence):**

```systemverilog
class apb_traffic_seq extends uvm_sequence #(apb_transaction);
    `uvm_object_utils(apb_traffic_seq)

    function new(string name = "apb_traffic_seq");
        super.new(name);
    endfunction

    virtual task body();
        apb_write_seq wr_seq;
        apb_read_seq  rd_seq;

        // Write phase
        wr_seq = apb_write_seq::type_id::create("wr_seq");
        wr_seq.num_writes = 10;
        wr_seq.start(m_sequencer);

        // Read-back phase
        rd_seq = apb_read_seq::type_id::create("rd_seq");
        rd_seq.num_reads = 10;
        rd_seq.start(m_sequencer);
    endtask
endclass
```

---

### 25. `uvm_driver`

`uvm_driver` is a `uvm_component` that receives `uvm_sequence_item` objects from a sequencer and drives them onto the DUT interface.

**Internal methods and ports:**

| Member | Type | Purpose |
|--------|------|---------|
| `seq_item_port` | `uvm_seq_item_pull_port` | Port connecting to the sequencer |
| `rsp_port` | `uvm_analysis_port` | Port for sending responses back |
| `get_next_item()` | Task (via port) | Blocking call — waits for an item from the sequencer |
| `try_next_item()` | Task (via port) | Non-blocking — returns null if no item available |
| `item_done()` | Function (via port) | Signals that the driver finished processing the item |

**Complete driver example:**

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
            `uvm_fatal("DRV", "Failed to get virtual interface")
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
        @(posedge vif.clk);
        vif.psel    <= 1;
        vif.paddr   <= txn.addr;
        vif.pwrite  <= txn.write;
        if (txn.write)
            vif.pwdata <= txn.data;

        @(posedge vif.clk);
        vif.penable <= 1;

        @(posedge vif.clk);
        wait(vif.pready);

        if (!txn.write)
            txn.data = vif.prdata;

        vif.psel    <= 0;
        vif.penable <= 0;
    endtask
endclass
```

---

### 26. `uvm_monitor`

`uvm_monitor` is a **passive** component that observes DUT interface activity without driving signals. It captures transactions and broadcasts them via an analysis port.

**Key characteristics:**

- Samples the DUT interface using a virtual interface
- Never drives signals
- Broadcasts observed transactions using `uvm_analysis_port`
- Used by both active and passive agents

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
        if (!uvm_config_db #(virtual apb_if)::get(this, "", "vif", vif))
            `uvm_fatal("MON", "Failed to get virtual interface")
    endfunction

    virtual task run_phase(uvm_phase phase);
        forever begin
            apb_transaction txn;
            collect_transaction(txn);
            ap.write(txn);     // Broadcast to all connected subscribers
        end
    endtask

    virtual task collect_transaction(output apb_transaction txn);
        txn = apb_transaction::type_id::create("txn");

        @(posedge vif.clk);
        wait(vif.psel && vif.penable && vif.pready);

        txn.addr  = vif.paddr;
        txn.write = vif.pwrite;
        txn.data  = vif.pwrite ? vif.pwdata : vif.prdata;

        `uvm_info("MON", txn.convert2string(), UVM_HIGH)
    endtask
endclass
```

---

### 27. `uvm_agent`

`uvm_agent` groups a driver, sequencer, and monitor into a reusable block. It supports two modes:

| Mode | `is_active` | Contains |
|------|-------------|----------|
| Active | `UVM_ACTIVE` | driver + sequencer + monitor |
| Passive | `UVM_PASSIVE` | monitor only |

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

        mon = apb_monitor::type_id::create("mon", this);

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

**The sequencer** is typically a simple typedef (no customization needed):

```systemverilog
typedef uvm_sequencer #(apb_transaction) apb_sequencer;
```

---

### 28. `uvm_scoreboard`

The scoreboard compares expected results (from a reference model) with actual results (from the monitor). It typically uses `uvm_analysis_imp` or `uvm_tlm_analysis_fifo` to receive transactions.

**Internal mechanism:**

- Implements `write()` method from `uvm_analysis_imp` to receive monitored transactions.
- Maintains a queue or associative array of expected transactions.
- Compares incoming actual transactions against expected values.

```systemverilog
class apb_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(apb_scoreboard)

    uvm_analysis_imp #(apb_transaction, apb_scoreboard) ap_imp;

    bit [31:0] memory_model[bit [31:0]];  // Reference model: addr -> data
    int match_count;
    int mismatch_count;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        ap_imp = new("ap_imp", this);
    endfunction

    virtual function void write(apb_transaction txn);
        if (txn.write) begin
            memory_model[txn.addr] = txn.data;
            `uvm_info("SCB", $sformatf("WRITE: addr=%0h data=%0h stored",
                      txn.addr, txn.data), UVM_MEDIUM)
        end else begin
            if (memory_model.exists(txn.addr)) begin
                if (txn.data == memory_model[txn.addr]) begin
                    match_count++;
                    `uvm_info("SCB", $sformatf("READ MATCH: addr=%0h data=%0h",
                              txn.addr, txn.data), UVM_MEDIUM)
                end else begin
                    mismatch_count++;
                    `uvm_error("SCB", $sformatf(
                        "READ MISMATCH: addr=%0h expected=%0h actual=%0h",
                        txn.addr, memory_model[txn.addr], txn.data))
                end
            end else begin
                `uvm_warning("SCB", $sformatf(
                    "READ from uninitialized addr=%0h", txn.addr))
            end
        end
    endfunction

    virtual function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info("SCB", $sformatf("Matches: %0d  Mismatches: %0d",
                  match_count, mismatch_count), UVM_NONE)
        if (mismatch_count > 0)
            `uvm_error("SCB", "TEST FAILED — mismatches detected")
        else
            `uvm_info("SCB", "TEST PASSED", UVM_NONE)
    endfunction
endclass
```

**Multi-port scoreboard** (when you need separate ports for expected and actual transactions):

```systemverilog
`uvm_analysis_imp_decl(_expected)
`uvm_analysis_imp_decl(_actual)

class dual_port_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(dual_port_scoreboard)

    uvm_analysis_imp_expected #(apb_transaction, dual_port_scoreboard) exp_imp;
    uvm_analysis_imp_actual   #(apb_transaction, dual_port_scoreboard) act_imp;

    apb_transaction expected_q[$];

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        exp_imp = new("exp_imp", this);
        act_imp = new("act_imp", this);
    endfunction

    virtual function void write_expected(apb_transaction txn);
        expected_q.push_back(txn);
    endfunction

    virtual function void write_actual(apb_transaction txn);
        apb_transaction exp_txn;
        if (expected_q.size() == 0) begin
            `uvm_error("SCB", "Received actual with no expected transaction")
            return;
        end
        exp_txn = expected_q.pop_front();
        if (!txn.compare(exp_txn))
            `uvm_error("SCB", $sformatf("MISMATCH:\n  Expected: %s\n  Actual:   %s",
                       exp_txn.convert2string(), txn.convert2string()))
    endfunction
endclass
```

---

### 29. `uvm_env`

`uvm_env` is a structural container that groups agents, scoreboards, and sub-environments.

```systemverilog
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
```

For SOC-level verification, environments nest:

```systemverilog
class soc_env extends uvm_env;
    `uvm_component_utils(soc_env)

    apb_env   apb;
    axi_env   axi;
    spi_env   spi;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        apb = apb_env::type_id::create("apb", this);
        axi = axi_env::type_id::create("axi", this);
        spi = spi_env::type_id::create("spi", this);
    endfunction
endclass
```

---

### 30. `uvm_test`

`uvm_test` is the top-level component that configures the environment and launches sequences.

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
            this, "env.agent", "is_active", UVM_ACTIVE);
    endfunction

    virtual function void end_of_elaboration_phase(uvm_phase phase);
        super.end_of_elaboration_phase(phase);
        uvm_top.print_topology();
    endfunction
endclass

class apb_write_test extends apb_base_test;
    `uvm_component_utils(apb_write_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual task run_phase(uvm_phase phase);
        apb_write_seq seq;

        phase.raise_objection(this);

        seq = apb_write_seq::type_id::create("seq");
        seq.num_writes = 100;
        seq.start(env.agent.sqr);

        phase.drop_objection(this);
    endtask
endclass
```

**Running a specific test from the command line:**

```bash
+UVM_TESTNAME=apb_write_test
```

---

### 31. UVM Factory — Create, Override, Substitute

The UVM factory is a design pattern that decouples object construction from class identity. Instead of calling `new()`, you call `type_id::create()`. This allows runtime substitution of class types without modifying any source code.

#### 31.1 — Factory Registration

Every class must register with the factory using one of these macros:

| Macro | Use For |
|-------|---------|
| `` `uvm_object_utils(ClassName) `` | Classes extending `uvm_object` / `uvm_sequence_item` / `uvm_sequence` |
| `` `uvm_component_utils(ClassName) `` | Classes extending `uvm_component` |
| `` `uvm_object_param_utils(ClassName #(P)) `` | Parameterized objects |
| `` `uvm_component_param_utils(ClassName #(P)) `` | Parameterized components |

**What the macro does internally:**

```systemverilog
// `uvm_object_utils(my_transaction) expands roughly to:
typedef uvm_object_registry #(my_transaction, "my_transaction") type_id;
static function type_id get_type();
    return type_id::get();
endfunction
virtual function uvm_object_wrapper get_object_type();
    return type_id::get();
endfunction
virtual function string get_type_name();
    return "my_transaction";
endfunction
```

#### 31.2 — Factory Creation

```systemverilog
// Object creation (for uvm_object derivatives)
my_transaction txn;
txn = my_transaction::type_id::create("txn");

// Component creation (requires parent handle)
apb_driver drv;
drv = apb_driver::type_id::create("drv", this);
```

#### 31.3 — Factory Overrides

Overrides substitute one class for another without changing the code that calls `create()`.

**Type override** — all instances of original type become the override type:

```systemverilog
class apb_error_transaction extends apb_transaction;
    `uvm_object_utils(apb_error_transaction)

    rand bit inject_error;

    constraint error_rate {
        inject_error dist { 1 := 10, 0 := 90 };  // 10% error injection
    }

    function new(string name = "apb_error_transaction");
        super.new(name);
    endfunction
endclass

// In the test:
virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    apb_transaction::type_id::set_type_override(apb_error_transaction::get_type());
endfunction
```

Now every `apb_transaction::type_id::create()` call in the entire testbench returns an `apb_error_transaction`.

**Instance override** — only a specific instance path is affected:

```systemverilog
apb_transaction::type_id::set_inst_override(
    apb_error_transaction::get_type(),
    "uvm_test_top.env.agent.sqr.*"   // Only in this agent's sequencer
);
```

**Command-line overrides:**

```bash
+uvm_set_type_override=apb_transaction,apb_error_transaction
+uvm_set_inst_override=apb_transaction,apb_error_transaction,uvm_test_top.env.agent.*
```

**Printing the factory contents:**

```systemverilog
factory.print();
```

---

### 32. UVM Configuration Database (`uvm_config_db`)

`uvm_config_db` is a hierarchical key-value store for passing configuration data between components without direct references.

**API:**

```systemverilog
// Set a value (typically in a higher-level component or test)
uvm_config_db #(T)::set(uvm_component context, string inst_name, string field_name, T value);

// Get a value (typically in build_phase of the target component)
uvm_config_db #(T)::get(uvm_component context, string inst_name, string field_name, ref T value);
```

**Common uses:**

```systemverilog
// Pass virtual interface from top module to UVM components
// In top-level module:
initial begin
    uvm_config_db #(virtual apb_if)::set(null, "uvm_test_top.*", "vif", apb_intf);
    run_test();
end

// In driver's build_phase:
virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(virtual apb_if)::get(this, "", "vif", vif))
        `uvm_fatal("CFG", "Cannot get virtual interface")
endfunction
```

**Pass scalar configuration:**

```systemverilog
// In test
uvm_config_db #(int)::set(this, "env.agent", "num_retries", 5);
uvm_config_db #(uvm_active_passive_enum)::set(this, "env.agent", "is_active", UVM_PASSIVE);

// In agent
int num_retries;
if (!uvm_config_db #(int)::get(this, "", "num_retries", num_retries))
    num_retries = 3;  // Default
```

**Hierarchical matching rules:**

| Context | Instance name | Field name | Matches |
|---------|---------------|------------|---------|
| `this` | `"env.agent"` | `"vif"` | `uvm_test_top.env.agent` |
| `this` | `"env.*"` | `"vif"` | All components under `env` |
| `null` | `"uvm_test_top.*"` | `"vif"` | All components in the testbench |
| `null` | `"*"` | `"vif"` | Every component everywhere |

**Debugging the config_db:**

```bash
+UVM_CONFIG_DB_TRACE    # Print every set/get operation
```

---

### 33. UVM TLM (Transaction-Level Modeling)

TLM provides standardized communication channels between components, decoupling producers from consumers.

#### 33.1 — Analysis Ports (1-to-N broadcast)

The most common TLM construct in UVM. One writer, many readers.

```
Monitor ──── analysis_port ────┬──── Scoreboard (analysis_imp)
                                ├──── Coverage  (analysis_imp)
                                └──── Logger    (analysis_imp)
```

```systemverilog
// Producer side (e.g., monitor)
uvm_analysis_port #(apb_transaction) ap;
ap = new("ap", this);
ap.write(txn);   // Broadcasts to all connected subscribers

// Consumer side (e.g., scoreboard)
uvm_analysis_imp #(apb_transaction, apb_scoreboard) ap_imp;
ap_imp = new("ap_imp", this);

function void write(apb_transaction txn);
    // Process the transaction
endfunction

// Connection (in env's connect_phase)
monitor.ap.connect(scoreboard.ap_imp);
```

#### 33.2 — TLM FIFOs

When the consumer needs to process transactions asynchronously (in its own thread), use a FIFO:

```systemverilog
class my_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(my_scoreboard)

    uvm_tlm_analysis_fifo #(apb_transaction) fifo;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        fifo = new("fifo", this);
    endfunction

    virtual task run_phase(uvm_phase phase);
        apb_transaction txn;
        forever begin
            fifo.get(txn);    // Blocking — waits for a transaction
            process_txn(txn);
        end
    endtask
endclass

// Connection: monitor.ap.connect(scoreboard.fifo.analysis_export);
```

#### 33.3 — Blocking Put/Get Ports

For point-to-point communication:

```systemverilog
// Producer
uvm_blocking_put_port #(apb_transaction) put_port;
put_port.put(txn);   // Blocking

// Consumer
uvm_blocking_put_imp #(apb_transaction, consumer_class) put_imp;
task put(apb_transaction txn);
    // Process
endtask
```

**TLM port summary:**

| Port Type | Direction | Blocking | Broadcast |
|-----------|-----------|----------|-----------|
| `uvm_analysis_port` | Producer → N consumers | Non-blocking (`write`) | Yes |
| `uvm_blocking_put_port` | Producer → 1 consumer | Yes | No |
| `uvm_blocking_get_port` | Consumer ← 1 producer | Yes | No |
| `uvm_tlm_analysis_fifo` | Buffered consumer | Yes (via `get`) | N/A |
| `uvm_tlm_fifo` | Buffered bidirectional | Yes | No |

---

### 34. Field Macros and Automation

UVM field macros automate `copy`, `compare`, `print`, `pack`, and `unpack` without manually writing `do_*` methods. They are controversial (performance overhead, debug difficulty) but useful for prototyping.

```systemverilog
class apb_transaction extends uvm_sequence_item;
    `uvm_object_utils_begin(apb_transaction)
        `uvm_field_int(addr,   UVM_ALL_ON | UVM_HEX)
        `uvm_field_int(data,   UVM_ALL_ON | UVM_HEX)
        `uvm_field_int(write,  UVM_ALL_ON | UVM_BIN)
        `uvm_field_string(comment, UVM_ALL_ON)
        `uvm_field_enum(op_e, op, UVM_ALL_ON)
        `uvm_field_queue_int(burst_data, UVM_ALL_ON | UVM_HEX)
    `uvm_object_utils_end

    rand bit [31:0] addr;
    rand bit [31:0] data;
    rand bit        write;
    string          comment;
    op_e            op;
    bit [31:0]      burst_data[$];

    function new(string name = "apb_transaction");
        super.new(name);
    endfunction
endclass
```

**Available field macros:**

| Macro | Data Type |
|-------|-----------|
| `` `uvm_field_int `` | Integral types (`bit`, `logic`, `int`, `byte`, etc.) |
| `` `uvm_field_string `` | `string` |
| `` `uvm_field_object `` | `uvm_object` derivatives |
| `` `uvm_field_enum `` | Enum types |
| `` `uvm_field_real `` | `real` |
| `` `uvm_field_event `` | `event` |
| `` `uvm_field_array_int `` | Dynamic arrays of integral |
| `` `uvm_field_queue_int `` | Queues of integral |
| `` `uvm_field_aa_int_string `` | Associative arrays (int indexed by string) |
| `` `uvm_field_sarray_int `` | Static arrays of integral |

**Flag values:**

| Flag | Effect |
|------|--------|
| `UVM_ALL_ON` | Enable all operations |
| `UVM_NOPRINT` | Exclude from `print()` |
| `UVM_NOCOMPARE` | Exclude from `compare()` |
| `UVM_NOCOPY` | Exclude from `copy()` |
| `UVM_NOPACK` | Exclude from `pack()/unpack()` |
| `UVM_HEX` | Print in hexadecimal |
| `UVM_DEC` | Print in decimal |
| `UVM_BIN` | Print in binary |
| `UVM_UNSIGNED` | Print as unsigned |

**Trade-offs:**

| Approach | Pros | Cons |
|----------|------|------|
| Field macros | Less code, automatic operations | Performance overhead, opaque debugging |
| Manual `do_*` methods | Full control, better performance | More code to maintain |
| Recommendation | Use field macros for prototyping | Switch to manual `do_*` for performance-critical code |

---

### 35. UVM Reporting and Messaging

UVM provides a unified messaging system with severity levels, verbosity control, and action configuration.

#### 35.1 — Message Macros

```systemverilog
`uvm_info   ("TAG", "message string", UVM_MEDIUM)   // Informational
`uvm_warning("TAG", "message string")                // Warning
`uvm_error  ("TAG", "message string")                // Error (non-fatal)
`uvm_fatal  ("TAG", "message string")                // Fatal (stops simulation)
```

#### 35.2 — Verbosity Levels

| Level | Value | Typical Use |
|-------|-------|-------------|
| `UVM_NONE` | 0 | Always displayed |
| `UVM_LOW` | 100 | Important milestones |
| `UVM_MEDIUM` | 200 | Default; routine operations |
| `UVM_HIGH` | 300 | Detailed debug information |
| `UVM_FULL` | 400 | Exhaustive trace |
| `UVM_DEBUG` | 500 | Developer-level debug |

**Controlling verbosity:**

```bash
+UVM_VERBOSITY=UVM_HIGH
```

Or per-component:

```systemverilog
env.agent.driver.set_report_verbosity_level(UVM_HIGH);
```

#### 35.3 — Severity Actions

| Action | Behavior |
|--------|----------|
| `UVM_NO_ACTION` | Suppress the message |
| `UVM_DISPLAY` | Print to stdout |
| `UVM_LOG` | Write to log file |
| `UVM_COUNT` | Increment error/warning count |
| `UVM_EXIT` | Terminate simulation |
| `UVM_CALL_HOOK` | Call the `report_hook()` callback |
| `UVM_STOP` | Invoke `$stop` (enter debugger) |

```systemverilog
// Demote a specific error to a warning
set_report_severity_id_override(UVM_ERROR, "EXPECTED_ERR", UVM_WARNING);

// Promote warnings to errors for a specific tag
set_report_severity_id_action(UVM_WARNING, "CRITICAL_WARN", UVM_ERROR | UVM_COUNT);

// Set max error count before simulation exits
set_report_max_quit_count(10);
```

#### 35.4 — Report Catcher

Intercept and modify messages before they are emitted:

```systemverilog
class error_demote_catcher extends uvm_report_catcher;
    `uvm_object_utils(error_demote_catcher)

    function new(string name = "error_demote_catcher");
        super.new(name);
    endfunction

    virtual function action_e catch_report();
        if (get_severity() == UVM_ERROR && get_id() == "EXPECTED_ERR") begin
            set_severity(UVM_WARNING);
            set_action(UVM_DISPLAY);
            return THROW;
        end
        return THROW;
    endfunction
endclass

// Install the catcher:
error_demote_catcher catcher = new();
uvm_report_cb::add(null, catcher);
```

---

### 36. UVM Register Layer (`uvm_reg`)

The UVM register abstraction layer (RAL) models the DUT's register map, enabling automatic read/write verification, coverage collection, and front-door/back-door access.

#### 36.1 — Class Hierarchy

```
uvm_reg_block
├── uvm_reg_map       (address mapping)
├── uvm_reg           (individual register)
│   └── uvm_reg_field (bit-field within a register)
└── uvm_mem           (memory)
```

#### 36.2 — Register Field and Register Definition

```systemverilog
class ctrl_reg extends uvm_reg;
    `uvm_object_utils(ctrl_reg)

    rand uvm_reg_field enable;
    rand uvm_reg_field mode;
    rand uvm_reg_field reserved;

    function new(string name = "ctrl_reg");
        super.new(name, 32, UVM_NO_COVERAGE);
    endfunction

    virtual function void build();
        enable = uvm_reg_field::type_id::create("enable");
        enable.configure(this, 1, 0, "RW", 0, 1'b0, 1, 1, 0);
        //                     size, lsb, access, volatile, reset, has_reset, is_rand, individually_accessible

        mode = uvm_reg_field::type_id::create("mode");
        mode.configure(this, 2, 1, "RW", 0, 2'b00, 1, 1, 0);

        reserved = uvm_reg_field::type_id::create("reserved");
        reserved.configure(this, 29, 3, "RO", 0, 29'b0, 1, 0, 0);
    endfunction
endclass

class status_reg extends uvm_reg;
    `uvm_object_utils(status_reg)

    rand uvm_reg_field busy;
    rand uvm_reg_field error;
    rand uvm_reg_field done;

    function new(string name = "status_reg");
        super.new(name, 32, UVM_NO_COVERAGE);
    endfunction

    virtual function void build();
        busy = uvm_reg_field::type_id::create("busy");
        busy.configure(this, 1, 0, "RO", 1, 1'b0, 1, 0, 0);

        error = uvm_reg_field::type_id::create("error");
        error.configure(this, 1, 1, "W1C", 1, 1'b0, 1, 0, 0);

        done = uvm_reg_field::type_id::create("done");
        done.configure(this, 1, 2, "RO", 1, 1'b0, 1, 0, 0);
    endfunction
endclass
```

#### 36.3 — Register Block and Map

```systemverilog
class dut_reg_block extends uvm_reg_block;
    `uvm_object_utils(dut_reg_block)

    rand ctrl_reg   ctrl;
    rand status_reg status;

    uvm_reg_map map;

    function new(string name = "dut_reg_block");
        super.new(name, UVM_NO_COVERAGE);
    endfunction

    virtual function void build();
        ctrl = ctrl_reg::type_id::create("ctrl");
        ctrl.configure(this);
        ctrl.build();

        status = status_reg::type_id::create("status");
        status.configure(this);
        status.build();

        map = create_map("map", 'h0, 4, UVM_LITTLE_ENDIAN);
        map.add_reg(ctrl,   'h00, "RW");
        map.add_reg(status, 'h04, "RO");

        lock_model();
    endfunction
endclass
```

#### 36.4 — Using the Register Model

```systemverilog
// Front-door access (goes through the bus agent)
uvm_status_e status;
uvm_reg_data_t rdata;

reg_block.ctrl.write(status, 32'h0000_0003);  // Write enable=1, mode=01
reg_block.status.read(status, rdata);          // Read status register

// Field-level access
reg_block.ctrl.enable.set(1);
reg_block.ctrl.mode.set(2'b10);
reg_block.ctrl.update(status);   // Write all modified fields in one bus transaction

// Mirror check (compare DUT register with model)
reg_block.ctrl.mirror(status, UVM_CHECK);

// Back-door access (direct RTL path, no bus transaction)
reg_block.ctrl.write(status, 32'h0000_0005, .path(UVM_BACKDOOR));
```

#### 36.5 — Built-in Register Test Sequences

UVM provides pre-built sequences for common register verification tasks:

```systemverilog
// In test's run_phase:
uvm_reg_hw_reset_seq reset_seq = uvm_reg_hw_reset_seq::type_id::create("reset_seq");
reset_seq.model = reg_block;
reset_seq.start(env.agent.sqr);

uvm_reg_bit_bash_seq bit_bash = uvm_reg_bit_bash_seq::type_id::create("bit_bash");
bit_bash.model = reg_block;
bit_bash.start(env.agent.sqr);
```

| Sequence | What It Tests |
|----------|---------------|
| `uvm_reg_hw_reset_seq` | All registers read back their reset values |
| `uvm_reg_bit_bash_seq` | Walking-1 / walking-0 on RW fields |
| `uvm_reg_access_seq` | Front-door vs. back-door consistency |
| `uvm_reg_mem_access_seq` | Memory read/write access |

---

### 37. Putting It All Together — Full UVM Testbench Example

This section walks through a complete, minimal UVM testbench for an APB slave peripheral. All component files are available in the `examples/` directory.

#### 37.1 — APB Interface

```systemverilog
interface apb_if(input logic clk, input logic rst_n);
    logic        psel;
    logic        penable;
    logic        pwrite;
    logic [31:0] paddr;
    logic [31:0] pwdata;
    logic [31:0] prdata;
    logic        pready;
    logic        pslverr;

    clocking driver_cb @(posedge clk);
        output psel, penable, pwrite, paddr, pwdata;
        input  prdata, pready, pslverr;
    endclocking

    clocking monitor_cb @(posedge clk);
        input psel, penable, pwrite, paddr, pwdata, prdata, pready, pslverr;
    endclocking

    modport driver  (clocking driver_cb, input clk, rst_n);
    modport monitor (clocking monitor_cb, input clk, rst_n);
endinterface
```

#### 37.2 — Simple APB Slave DUT

```systemverilog
module apb_slave (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        psel,
    input  logic        penable,
    input  logic        pwrite,
    input  logic [31:0] paddr,
    input  logic [31:0] pwdata,
    output logic [31:0] prdata,
    output logic        pready,
    output logic        pslverr
);
    logic [31:0] mem [0:255];

    assign pslverr = 0;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pready <= 0;
            prdata <= 0;
        end else begin
            if (psel && penable) begin
                pready <= 1;
                if (pwrite)
                    mem[paddr[9:2]] <= pwdata;
                else
                    prdata <= mem[paddr[9:2]];
            end else begin
                pready <= 0;
            end
        end
    end
endmodule
```

#### 37.3 — Top-Level Testbench Module

```systemverilog
module tb_top;
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    logic clk = 0;
    logic rst_n = 0;

    always #5 clk = ~clk;

    apb_if apb_intf(clk, rst_n);

    apb_slave dut (
        .clk     (clk),
        .rst_n   (rst_n),
        .psel    (apb_intf.psel),
        .penable (apb_intf.penable),
        .pwrite  (apb_intf.pwrite),
        .paddr   (apb_intf.paddr),
        .pwdata  (apb_intf.pwdata),
        .prdata  (apb_intf.prdata),
        .pready  (apb_intf.pready),
        .pslverr (apb_intf.pslverr)
    );

    initial begin
        uvm_config_db #(virtual apb_if)::set(null, "uvm_test_top.*", "vif", apb_intf);
        run_test();
    end

    initial begin
        rst_n = 0;
        #100;
        rst_n = 1;
    end
endmodule
```

#### 37.4 — Bringing It Together

The components described in Sections 23–30 (transaction, sequence, driver, monitor, agent, scoreboard, env, test) are assembled hierarchically:

```
tb_top (module)
├── clk, rst_n generation
├── apb_if instance
├── apb_slave DUT
└── UVM test (via run_test())
    └── uvm_test_top (apb_write_test)
        └── env (apb_env)
            ├── agent (apb_agent, UVM_ACTIVE)
            │   ├── sqr (apb_sequencer)
            │   ├── drv (apb_driver) ─── virtual interface ─── apb_if
            │   └── mon (apb_monitor) ── virtual interface ─── apb_if
            └── scoreboard (apb_scoreboard)
                └── connected to mon.ap
```

**Data flow:**

1. Test creates a sequence and starts it on the sequencer.
2. Sequence generates randomized `apb_transaction` items.
3. Driver pulls items from the sequencer, drives them on the APB interface.
4. Monitor observes the APB interface, constructs transaction objects, broadcasts via analysis port.
5. Scoreboard receives transactions, compares against a reference model.
6. Test drops its objection when the sequence completes, ending `run_phase`.
7. `report_phase` prints the pass/fail summary.

---

## Quick Reference Tables

### SystemVerilog Class Keywords

| Keyword | Purpose |
|---------|---------|
| `class ... endclass` | Define a class |
| `extends` | Inherit from a parent class |
| `virtual class` | Abstract class (cannot be instantiated) |
| `pure virtual` | Method with no body — must be overridden |
| `virtual function/task` | Enables dynamic dispatch (polymorphism) |
| `new()` | Constructor |
| `super` | Reference to parent class |
| `this` | Reference to current instance |
| `local` | Member accessible only within the class |
| `protected` | Member accessible in class and subclasses |
| `static` | Member belongs to the class, not instances |
| `rand` / `randc` | Random / cyclic-random property |
| `constraint` | Constrained-random rule |

### UVM Registration Macros

| Macro | When to Use |
|-------|-------------|
| `` `uvm_object_utils(T) `` | Non-parameterized `uvm_object` / `uvm_sequence_item` / `uvm_sequence` |
| `` `uvm_component_utils(T) `` | Non-parameterized `uvm_component` |
| `` `uvm_object_param_utils(T) `` | Parameterized `uvm_object` |
| `` `uvm_component_param_utils(T) `` | Parameterized `uvm_component` |
| `` `uvm_object_utils_begin(T) ... `uvm_object_utils_end `` | With field macros |
| `` `uvm_component_utils_begin(T) ... `uvm_component_utils_end `` | With field macros |

### UVM Phase Execution Order

| # | Phase | Type | Direction |
|---|-------|------|-----------|
| 1 | `build_phase` | Function | Top-down |
| 2 | `connect_phase` | Function | Bottom-up |
| 3 | `end_of_elaboration_phase` | Function | Bottom-up |
| 4 | `start_of_simulation_phase` | Function | Bottom-up |
| 5 | `run_phase` | Task | Parallel |
| 6 | `extract_phase` | Function | Bottom-up |
| 7 | `check_phase` | Function | Bottom-up |
| 8 | `report_phase` | Function | Bottom-up |
| 9 | `final_phase` | Function | Top-down |

### Essential UVM Command-Line Switches

| Switch | Purpose |
|--------|---------|
| `+UVM_TESTNAME=<test>` | Select which test to run |
| `+UVM_VERBOSITY=<level>` | Set global verbosity (UVM_NONE through UVM_DEBUG) |
| `+UVM_CONFIG_DB_TRACE` | Trace config_db set/get operations |
| `+UVM_OBJECTION_TRACE` | Trace objection raise/drop |
| `+uvm_set_type_override=<orig>,<override>` | Factory type override from command line |
| `+uvm_set_inst_override=<orig>,<override>,<path>` | Factory instance override from command line |
| `+UVM_MAX_QUIT_COUNT=<N>` | Exit after N errors |
| `+UVM_TIMEOUT=<ns>` | Global simulation timeout |

---

*End of tutorial.*
