# SystemVerilog Classes and UVM: A Comprehensive Tutorial

A deep-dive guide covering SystemVerilog object-oriented programming from first principles through advanced UVM verification methodology, with fully worked examples and detailed explanations of every major UVM class's internal functions.

---

## Table of Contents

### Part 1 — SystemVerilog Object-Oriented Programming

1. [Classes: The Basics](#1-classes-the-basics)
2. [Properties and Methods](#2-properties-and-methods)
3. [Constructors and Object Lifetime](#3-constructors-and-object-lifetime)
4. [Encapsulation: `local` and `protected`](#4-encapsulation-local-and-protected)
5. [Inheritance](#5-inheritance)
6. [Polymorphism and Virtual Methods](#6-polymorphism-and-virtual-methods)
7. [Abstract Classes and Pure Virtual Methods](#7-abstract-classes-and-pure-virtual-methods)
8. [Parameterized (Generic) Classes](#8-parameterized-generic-classes)
9. [Static Members](#9-static-members)
10. [Copying Objects: Shallow vs Deep Copy](#10-copying-objects-shallow-vs-deep-copy)
11. [Typedef, Forward Declarations, and Scope Resolution](#11-typedef-forward-declarations-and-scope-resolution)
12. [Interface Classes](#12-interface-classes)
13. [Randomization and Constraints](#13-randomization-and-constraints)
14. [Interprocess Communication: Mailboxes and Semaphores](#14-interprocess-communication-mailboxes-and-semaphores)

### Part 2 — UVM Class Hierarchy and Internal Functions

15. [UVM Overview and Architecture](#15-uvm-overview-and-architecture)
16. [`uvm_void` and `uvm_object` — The Foundation](#16-uvm_void-and-uvm_object--the-foundation)
17. [`uvm_object` Core Methods in Detail](#17-uvm_object-core-methods-in-detail)
18. [`uvm_component` — The Structural Backbone](#18-uvm_component--the-structural-backbone)
19. [UVM Phases and the Phase Mechanism](#19-uvm-phases-and-the-phase-mechanism)
20. [`uvm_transaction` and `uvm_sequence_item`](#20-uvm_transaction-and-uvm_sequence_item)
21. [`uvm_sequence` and `uvm_sequencer`](#21-uvm_sequence-and-uvm_sequencer)
22. [`uvm_driver`](#22-uvm_driver)
23. [`uvm_monitor`](#23-uvm_monitor)
24. [`uvm_agent`](#24-uvm_agent)
25. [`uvm_scoreboard`](#25-uvm_scoreboard)
26. [`uvm_env`](#26-uvm_env)
27. [`uvm_test`](#27-uvm_test)

### Part 3 — UVM Infrastructure and Advanced Topics

28. [The UVM Factory](#28-the-uvm-factory)
29. [Configuration Database (`uvm_config_db`)](#29-configuration-database-uvm_config_db)
30. [Field Automation Macros (`uvm_field_*`)](#30-field-automation-macros-uvm_field_)
31. [TLM Ports and Communication](#31-tlm-ports-and-communication)
32. [UVM Reporting and Messaging](#32-uvm-reporting-and-messaging)
33. [Objection Mechanism](#33-objection-mechanism)
34. [UVM Register Layer (RAL) Overview](#34-uvm-register-layer-ral-overview)
35. [Virtual Sequences and Virtual Sequencers](#35-virtual-sequences-and-virtual-sequencers)
36. [Coverage-Driven Verification with UVM](#36-coverage-driven-verification-with-uvm)
37. [Complete UVM Testbench Example](#37-complete-uvm-testbench-example)

---

## Part 1 — SystemVerilog Object-Oriented Programming

---

### 1. Classes: The Basics

A **class** in SystemVerilog is a user-defined data type that bundles data (properties) and functions/tasks (methods) into a single unit. Unlike modules, classes are dynamic — objects are created at run-time on the heap.

```systemverilog
class Packet;
  // Properties (data members)
  bit [7:0]  src_addr;
  bit [7:0]  dst_addr;
  bit [31:0] payload;
  bit        valid;

  // Method (function member)
  function void display();
    $display("Packet: src=%0h dst=%0h payload=%0h valid=%0b",
             src_addr, dst_addr, payload, valid);
  endfunction
endclass
```

**Creating and using an object:**

```systemverilog
module tb;
  initial begin
    Packet pkt;           // Declare a handle (null by default)
    pkt = new();          // Allocate the object on the heap
    pkt.src_addr = 8'hA0;
    pkt.dst_addr = 8'hB5;
    pkt.payload  = 32'hDEAD_BEEF;
    pkt.valid    = 1;
    pkt.display();
  end
endmodule
```

Key points:

- `Packet pkt;` declares a **handle** (pointer), not the object itself. It is `null` until `new()` is called.
- `pkt = new();` allocates memory and returns a handle to the new object.
- Objects are garbage-collected when no handles reference them.

#### Handles vs Objects

```systemverilog
Packet p1, p2;
p1 = new();       // Create object A — p1 points to A
p2 = p1;          // p2 now also points to object A (NOT a copy)
p2.src_addr = 8'hFF;
$display(p1.src_addr);  // Prints FF — same object
```

Assigning one handle to another copies the **reference**, not the object. Both handles point to the same underlying data.

---

### 2. Properties and Methods

**Properties** are variables declared inside a class. They can be of any SystemVerilog type: `bit`, `logic`, `int`, `string`, arrays, queues, associative arrays, or even handles to other classes.

```systemverilog
class Register;
  string     name;
  bit [31:0] value;
  bit [31:0] reset_value;
  bit [31:0] field_mask[$];    // Queue of field masks

  function void reset();
    value = reset_value;
  endfunction

  function void write(bit [31:0] data);
    value = data;
  endfunction

  function bit [31:0] read();
    return value;
  endfunction

  function void display();
    $display("[%s] value=0x%08h reset=0x%08h", name, value, reset_value);
  endfunction
endclass
```

**Methods** come in two flavors:

| Keyword    | Can consume time? | Can call `@`, `#`, `wait`? |
|------------|:-----------------:|:--------------------------:|
| `function` | No                | No                         |
| `task`     | Yes               | Yes                        |

```systemverilog
class BusDriver;
  virtual interface bus_if vif;

  // Function — zero-time
  function bit [31:0] calc_parity(bit [31:0] data);
    return ^data;
  endfunction

  // Task — consumes simulation time
  task drive_transaction(bit [31:0] addr, bit [31:0] data);
    @(posedge vif.clk);
    vif.addr  <= addr;
    vif.data  <= data;
    vif.valid <= 1'b1;
    @(posedge vif.clk);
    vif.valid <= 1'b0;
  endtask
endclass
```

#### `this` Keyword

When a method parameter has the same name as a property, use `this` to disambiguate:

```systemverilog
class Packet;
  int id;

  function new(int id);
    this.id = id;   // this.id = property, id = parameter
  endfunction
endclass
```

---

### 3. Constructors and Object Lifetime

Every class has an implicit constructor `new()`. You can define a custom one:

```systemverilog
class Packet;
  bit [7:0] src_addr;
  bit [7:0] dst_addr;
  int       id;

  function new(bit [7:0] src = 0, bit [7:0] dst = 0);
    this.src_addr = src;
    this.dst_addr = dst;
    this.id = $urandom();
  endfunction
endclass
```

Usage:

```systemverilog
Packet p1 = new();                // Uses defaults: src=0, dst=0
Packet p2 = new(8'hAA, 8'hBB);   // src=0xAA, dst=0xBB
Packet p3 = new(.dst(8'hCC));     // Named argument: src=0, dst=0xCC
```

#### Object Lifetime and Garbage Collection

Objects live on the heap and persist as long as at least one handle references them:

```systemverilog
function Packet create_packet();
  Packet p = new();
  p.src_addr = 8'hFF;
  return p;           // Object survives because it is returned
endfunction

initial begin
  Packet my_pkt;
  my_pkt = create_packet();  // my_pkt holds the only reference
  my_pkt = null;              // Object is now unreachable — garbage collected
end
```

---

### 4. Encapsulation: `local` and `protected`

SystemVerilog provides two access qualifiers:

| Qualifier   | Accessible from same class? | Accessible from subclass? | Accessible externally? |
|-------------|:---------------------------:|:-------------------------:|:----------------------:|
| *(default)* | Yes                         | Yes                       | Yes                    |
| `protected` | Yes                         | Yes                       | No                     |
| `local`     | Yes                         | No                        | No                     |

```systemverilog
class Account;
  local    int balance;       // Only this class
  protected string owner;     // This class + subclasses
  int      id;                // Accessible everywhere

  function new(string owner, int initial_balance);
    this.owner   = owner;
    this.balance = initial_balance;
    this.id      = $urandom();
  endfunction

  function void deposit(int amount);
    if (amount > 0) balance += amount;
  endfunction

  function int get_balance();
    return balance;
  endfunction
endclass

class PremiumAccount extends Account;
  function void display();
    // $display(balance);  // ILLEGAL — balance is local to Account
    $display("Owner: %s", owner);  // OK — owner is protected
  endfunction
endclass
```

---

### 5. Inheritance

A subclass (`extends`) inherits all non-local properties and methods of its parent and can add new ones or override existing ones.

```systemverilog
class Transaction;
  bit [31:0] addr;
  bit [31:0] data;
  bit        rw;         // 0 = read, 1 = write

  function void display();
    $display("Transaction: addr=%0h data=%0h rw=%0b", addr, data, rw);
  endfunction
endclass

class BurstTransaction extends Transaction;
  int burst_length;
  bit [2:0] burst_type;  // FIXED, INCR, WRAP

  function void display();
    super.display();  // Call parent's display
    $display("  burst_length=%0d burst_type=%0b", burst_length, burst_type);
  endfunction
endclass
```

#### `super` Keyword

`super` calls the parent class's version of a method or constructor:

```systemverilog
class Base;
  int x;
  function new(int x);
    this.x = x;
  endfunction
endclass

class Derived extends Base;
  int y;
  function new(int x, int y);
    super.new(x);     // Must call parent constructor explicitly
    this.y = y;
  endfunction
endclass
```

#### Multi-Level Inheritance

```systemverilog
class Animal;
  string name;
  function void speak();
    $display("%s: ...", name);
  endfunction
endclass

class Dog extends Animal;
  function void speak();
    $display("%s: Woof!", name);
  endfunction
endclass

class GoldenRetriever extends Dog;
  function void fetch();
    $display("%s fetches the ball!", name);
  endfunction
endclass
```

---

### 6. Polymorphism and Virtual Methods

Polymorphism lets a parent-type handle invoke the correct subclass method at runtime. This requires the `virtual` keyword.

#### Without `virtual` (static dispatch — wrong behavior)

```systemverilog
class Base;
  function void greet();
    $display("Hello from Base");
  endfunction
endclass

class Child extends Base;
  function void greet();
    $display("Hello from Child");
  endfunction
endclass

initial begin
  Base b;
  Child c = new();
  b = c;          // Parent handle pointing to child object
  b.greet();      // Prints "Hello from Base" — WRONG!
end
```

#### With `virtual` (dynamic dispatch — correct behavior)

```systemverilog
class Base;
  virtual function void greet();
    $display("Hello from Base");
  endfunction
endclass

class Child extends Base;
  virtual function void greet();
    $display("Hello from Child");
  endfunction
endclass

initial begin
  Base b;
  Child c = new();
  b = c;
  b.greet();      // Prints "Hello from Child" — CORRECT!
end
```

**Rule of thumb:** Mark every method `virtual` unless you have a specific reason not to. UVM uses `virtual` pervasively.

#### Casting

To go from a parent handle to a child handle, use `$cast`:

```systemverilog
Base b;
Child c_orig = new();
Child c_back;

b = c_orig;             // Implicit upcast — always legal

if (!$cast(c_back, b))  // Explicit downcast — checked at runtime
  $fatal("Cast failed");

c_back.greet();          // Now we can access Child-specific methods
```

---

### 7. Abstract Classes and Pure Virtual Methods

A **pure virtual** method has no body in the base class. Any class containing a pure virtual method is abstract and cannot be instantiated.

```systemverilog
virtual class Shape;
  pure virtual function real area();
  pure virtual function void display();

  function real compare_area(Shape other);
    return this.area() - other.area();
  endfunction
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

```systemverilog
initial begin
  Circle circ = new(5.0);
  Rectangle rect = new(4.0, 6.0);

  // Shape s = new();  // ILLEGAL — Shape is abstract

  circ.display();   // Circle: radius=5.00 area=78.54
  rect.display();   // Rectangle: 4.00 x 6.00 area=24.00

  Shape shapes[$];
  shapes.push_back(circ);
  shapes.push_back(rect);

  foreach (shapes[i])
    shapes[i].display();  // Polymorphic dispatch
end
```

---

### 8. Parameterized (Generic) Classes

Parameterized classes are templates that accept type or value parameters:

```systemverilog
class Stack #(type T = int, int DEPTH = 16);
  local T data[$];

  function void push(T item);
    if (data.size() < DEPTH)
      data.push_back(item);
    else
      $error("Stack overflow");
  endfunction

  function T pop();
    if (data.size() > 0)
      return data.pop_back();
    else begin
      $error("Stack underflow");
      return T'(0);
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

Usage with different types:

```systemverilog
Stack #(int, 32)        int_stack   = new();
Stack #(bit [7:0], 256) byte_stack  = new();
Stack #(string)         str_stack   = new();   // Default DEPTH=16

initial begin
  int_stack.push(42);
  int_stack.push(99);
  $display("Popped: %0d", int_stack.pop());    // 99

  byte_stack.push(8'hAB);

  str_stack.push("hello");
  str_stack.push("world");
  $display("Popped: %s", str_stack.pop());     // world
end
```

---

### 9. Static Members

Static properties and methods belong to the class itself, not individual objects.

```systemverilog
class Packet;
  static int pkt_count = 0;    // Shared across all instances
  int        id;
  bit [31:0] data;

  function new();
    pkt_count++;
    id = pkt_count;
  endfunction

  static function int get_count();
    return pkt_count;
  endfunction

  static function void reset_count();
    pkt_count = 0;
  endfunction
endclass
```

```systemverilog
initial begin
  Packet p1 = new();
  Packet p2 = new();
  Packet p3 = new();

  $display("Total packets: %0d", Packet::get_count());  // 3
  $display("p2.id = %0d", p2.id);                       // 2

  Packet::reset_count();
  $display("After reset: %0d", Packet::get_count());    // 0
end
```

Static members are accessed with `ClassName::member` (scope resolution operator) or through any instance handle.

---

### 10. Copying Objects: Shallow vs Deep Copy

#### Shallow Copy

```systemverilog
class Header;
  bit [7:0] src, dst;
endclass

class Packet;
  int        id;
  bit [31:0] data;
  Header     hdr;  // Handle to another object
endclass
```

```systemverilog
Packet p1 = new();
p1.id   = 1;
p1.data = 32'hAAAA;
p1.hdr  = new();
p1.hdr.src = 8'h10;

Packet p2 = new p1;    // Shallow copy

$display(p2.id);        // 1 — copied
$display(p2.data);      // 0x0000AAAA — copied

p2.id = 2;
$display(p1.id);        // Still 1 — scalar was copied

p2.hdr.src = 8'hFF;
$display(p1.hdr.src);   // FF! — hdr handle was copied, pointing to same object
```

`new p1` creates a **shallow copy**: scalars and arrays are duplicated, but object handles are copied (not the objects they point to).

#### Deep Copy (Manual)

```systemverilog
class Header;
  bit [7:0] src, dst;

  function Header copy();
    Header h = new();
    h.src = this.src;
    h.dst = this.dst;
    return h;
  endfunction
endclass

class Packet;
  int        id;
  bit [31:0] data;
  Header     hdr;

  function Packet copy();
    Packet p = new();
    p.id   = this.id;
    p.data = this.data;
    p.hdr  = this.hdr.copy();   // Deep copy the sub-object
    return p;
  endfunction
endclass
```

```systemverilog
Packet p1 = new();
p1.hdr = new();
p1.hdr.src = 8'h10;

Packet p2 = p1.copy();       // Deep copy
p2.hdr.src = 8'hFF;
$display(p1.hdr.src);        // 10 — independent copy
```

---

### 11. Typedef, Forward Declarations, and Scope Resolution

#### Forward Declaration

When two classes reference each other, use a forward declaration:

```systemverilog
typedef class Node;    // Forward declaration

class LinkedList;
  Node head;

  function void add(int data);
    Node n = new(data, head);
    head = n;
  endfunction
endclass

class Node;
  int  data;
  Node next;

  function new(int data, Node next = null);
    this.data = data;
    this.next = next;
  endfunction
endclass
```

#### Scope Resolution (`::`)

Used to access static members, enum values inside classes, and type parameters:

```systemverilog
class Config;
  typedef enum {LOW, MEDIUM, HIGH} priority_e;
  static priority_e default_priority = MEDIUM;
endclass

initial begin
  Config::priority_e p = Config::HIGH;
  $display("Priority: %s", p.name());    // HIGH
end
```

---

### 12. Interface Classes

Interface classes (IEEE 1800-2012+) define a contract that implementing classes must fulfill. They support a form of multiple inheritance.

```systemverilog
interface class Printable;
  pure virtual function void print();
endclass

interface class Comparable;
  pure virtual function bit is_equal(Comparable other);
endclass

class DataPacket implements Printable, Comparable;
  bit [31:0] data;
  bit [7:0]  id;

  function new(bit [31:0] d, bit [7:0] i);
    data = d;
    id = i;
  endfunction

  virtual function void print();
    $display("DataPacket[%0d]: data=0x%08h", id, data);
  endfunction

  virtual function bit is_equal(Comparable other);
    DataPacket other_pkt;
    if (!$cast(other_pkt, other)) return 0;
    return (this.data == other_pkt.data) && (this.id == other_pkt.id);
  endfunction
endclass
```

---

### 13. Randomization and Constraints

SystemVerilog's constrained random verification is a cornerstone of modern verification. Classes can declare `rand` and `randc` variables with `constraint` blocks.

```systemverilog
class EthernetFrame;
  rand  bit [47:0] dst_mac;
  rand  bit [47:0] src_mac;
  rand  bit [15:0] eth_type;
  rand  bit [7:0]  payload[];
  randc bit [2:0]  priority;    // cyclic — each value before repeat

  constraint c_payload_size {
    payload.size() inside {[46:1500]};
  }

  constraint c_eth_type {
    eth_type inside {16'h0800, 16'h0806, 16'h86DD};  // IPv4, ARP, IPv6
  }

  constraint c_unicast_dst {
    dst_mac[0] == 0;   // Unicast — LSB of first byte is 0
  }

  function void display();
    $display("Ethernet Frame:");
    $display("  DST: %012h  SRC: %012h", dst_mac, src_mac);
    $display("  Type: %04h  Payload: %0d bytes  Priority: %0d",
             eth_type, payload.size(), priority);
  endfunction
endclass
```

#### Constraint Features

```systemverilog
class AdvancedPacket;
  rand bit [7:0] addr;
  rand bit [7:0] data;
  rand int       delay;
  rand bit       is_write;

  // Implication
  constraint c_write_implies {
    is_write -> data != 0;
  }

  // Distribution
  constraint c_delay_dist {
    delay dist {[0:5] := 80, [6:20] := 15, [21:100] := 5};
  }

  // Conditional constraint
  constraint c_addr_range {
    if (is_write)
      addr inside {[8'h00:8'h3F]};
    else
      addr inside {[8'h40:8'h7F]};
  }

  // Solve ordering
  constraint c_solve_order {
    solve is_write before addr;
    solve is_write before data;
  }
endclass
```

#### Inline Constraints and `randomize() with`

```systemverilog
AdvancedPacket pkt = new();

// Inline constraint — adds to existing constraints
if (!pkt.randomize() with {
  addr == 8'h10;
  delay < 10;
})
  $fatal("Randomization failed");

// Turn off a constraint
pkt.c_delay_dist.constraint_mode(0);
pkt.randomize();

// Disable randomization of a variable
pkt.addr.rand_mode(0);
pkt.addr = 8'hFF;
pkt.randomize();
```

#### `pre_randomize()` and `post_randomize()`

```systemverilog
class Packet;
  rand bit [7:0] data[];
  bit  [15:0]    checksum;

  constraint c_size { data.size() inside {[4:64]}; }

  function void pre_randomize();
    $display("About to randomize...");
  endfunction

  function void post_randomize();
    checksum = 0;
    foreach (data[i])
      checksum += data[i];
    $display("Checksum computed: %0h", checksum);
  endfunction
endclass
```

---

### 14. Interprocess Communication: Mailboxes and Semaphores

These are parameterized built-in classes critical for testbench communication.

#### Mailbox

```systemverilog
class Producer;
  mailbox #(int) mbx;

  function new(mailbox #(int) mbx);
    this.mbx = mbx;
  endfunction

  task run();
    for (int i = 0; i < 10; i++) begin
      mbx.put(i);
      $display("[%0t] Producer sent: %0d", $time, i);
      #10;
    end
  endtask
endclass

class Consumer;
  mailbox #(int) mbx;

  function new(mailbox #(int) mbx);
    this.mbx = mbx;
  endfunction

  task run();
    int val;
    forever begin
      mbx.get(val);
      $display("[%0t] Consumer received: %0d", $time, val);
    end
  endtask
endclass
```

```systemverilog
initial begin
  mailbox #(int) mbx = new();
  Producer prod = new(mbx);
  Consumer cons = new(mbx);

  fork
    prod.run();
    cons.run();
  join_any
end
```

#### Semaphore

```systemverilog
class SharedResource;
  semaphore sem;
  int shared_data;

  function new();
    sem = new(1);   // Binary semaphore (mutex)
  endfunction

  task access(string name, int value);
    sem.get(1);                              // Acquire lock
    $display("[%0t] %s acquired lock", $time, name);
    shared_data = value;
    #20;
    $display("[%0t] %s releasing lock, data=%0d", $time, name, shared_data);
    sem.put(1);                              // Release lock
  endtask
endclass
```

---

## Part 2 — UVM Class Hierarchy and Internal Functions

---

### 15. UVM Overview and Architecture

The **Universal Verification Methodology (UVM)** is a standardized class library built on top of SystemVerilog that provides:

- A base class hierarchy for building reusable verification components
- An object factory for flexible construction and substitution
- Phases that orchestrate the verification lifecycle
- A configuration database for parameterizing components
- TLM (Transaction Level Modeling) ports for inter-component communication
- Built-in reporting and messaging
- A register abstraction layer (RAL)

#### UVM Class Hierarchy (Simplified)

```
uvm_void
├── uvm_object
│   ├── uvm_transaction
│   │   └── uvm_sequence_item
│   ├── uvm_sequence
│   ├── uvm_reg_item
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
├── uvm_port_base
│   ├── uvm_analysis_port
│   ├── uvm_tlm_fifo
│   └── ...
└── uvm_factory
```

#### The Two Fundamental Branches

| Branch          | Purpose                            | Has name? | Has parent? | Persistent? |
|-----------------|-------------------------------------|:---------:|:-----------:|:-----------:|
| `uvm_object`    | Data / transactions / config       | Optional  | No          | No          |
| `uvm_component` | Structural verification components | Required  | Required    | Yes         |

---

### 16. `uvm_void` and `uvm_object` — The Foundation

#### `uvm_void`

The root of the UVM hierarchy. It is an empty abstract class that exists solely to provide a common base type for both `uvm_object` and `uvm_component`.

```systemverilog
virtual class uvm_void;
  // Completely empty — just a common ancestor
endclass
```

#### `uvm_object`

Every data-carrying class in UVM extends `uvm_object`. It provides:

- **Identity**: name, type name
- **Core data operations**: copy, clone, compare, print, pack, unpack, record
- **Factory registration hooks**

```systemverilog
class my_data extends uvm_object;
  `uvm_object_utils(my_data)     // Register with the factory

  int          value;
  string       label;
  bit [31:0]   address;

  function new(string name = "my_data");
    super.new(name);
  endfunction
endclass
```

The `uvm_object_utils` macro registers the class with the UVM factory and optionally provides default implementations of `get_type_name()`, `create()`, and other utility methods.

---

### 17. `uvm_object` Core Methods in Detail

These are the fundamental methods that every `uvm_object` (and its subclasses) can implement. Understanding them is essential for UVM mastery.

#### 17.1 `do_copy()` / `copy()` / `clone()`

**Purpose**: Create an exact duplicate of an object.

```systemverilog
// Method signatures (from uvm_object):
// extern virtual function void   copy(uvm_object rhs);
// extern virtual function void   do_copy(uvm_object rhs);
// extern virtual function uvm_object clone();
```

**How they work together**:
- `copy(rhs)` — Public API. Calls `do_copy(rhs)` internally after type checking.
- `do_copy(rhs)` — Override this in your class to define field-by-field copying.
- `clone()` — Calls `create()` (via factory) then `copy()`. Returns a new `uvm_object` handle.

```systemverilog
class apb_transaction extends uvm_sequence_item;
  `uvm_object_utils(apb_transaction)

  rand bit [31:0] addr;
  rand bit [31:0] data;
  rand bit        write;
  rand bit [3:0]  strobe;

  function new(string name = "apb_transaction");
    super.new(name);
  endfunction

  virtual function void do_copy(uvm_object rhs);
    apb_transaction rhs_cast;
    super.do_copy(rhs);      // Always call super first
    if (!$cast(rhs_cast, rhs))
      `uvm_fatal("COPY", "Cast failed in do_copy")
    this.addr   = rhs_cast.addr;
    this.data   = rhs_cast.data;
    this.write  = rhs_cast.write;
    this.strobe = rhs_cast.strobe;
  endfunction
endclass
```

**Usage**:

```systemverilog
apb_transaction t1 = apb_transaction::type_id::create("t1");
apb_transaction t2 = apb_transaction::type_id::create("t2");

t1.addr  = 32'h1000;
t1.data  = 32'hDEAD;
t1.write = 1;

t2.copy(t1);
$display("t2.addr = 0x%0h", t2.addr);   // 0x1000

// Or use clone (returns uvm_object, needs cast)
uvm_object t3_obj = t1.clone();
apb_transaction t3;
$cast(t3, t3_obj);
```

#### 17.2 `do_compare()` / `compare()`

**Purpose**: Field-by-field equality check between two objects.

```systemverilog
// Method signatures:
// extern virtual function bit compare(uvm_object rhs, uvm_comparer comparer = null);
// extern virtual function bit do_compare(uvm_object rhs, uvm_comparer comparer);
```

**How they work**:
- `compare(rhs)` calls `do_compare()` internally.
- Returns 1 if objects are equal, 0 if not.
- The `uvm_comparer` policy object controls comparison behavior (verbosity, max mismatches, etc.).

```systemverilog
virtual function bit do_compare(uvm_object rhs, uvm_comparer comparer);
  apb_transaction rhs_cast;
  bit status = super.do_compare(rhs, comparer);

  if (!$cast(rhs_cast, rhs))
    return 0;

  status &= comparer.compare_field_int("addr", this.addr, rhs_cast.addr, 32);
  status &= comparer.compare_field_int("data", this.data, rhs_cast.data, 32);
  status &= comparer.compare_field_int("write", this.write, rhs_cast.write, 1);
  status &= comparer.compare_field_int("strobe", this.strobe, rhs_cast.strobe, 4);

  return status;
endfunction
```

**Usage**:

```systemverilog
apb_transaction expected, actual;
// ... populate both ...

if (!actual.compare(expected))
  `uvm_error("COMPARE", "Transaction mismatch")
```

#### 17.3 `do_print()` / `print()` / `sprint()` / `convert2string()`

**Purpose**: Human-readable representation of the object.

```systemverilog
// Method signatures:
// extern virtual function void   print(uvm_printer printer = null);
// extern virtual function string sprint(uvm_printer printer = null);
// extern virtual function string convert2string();
// extern virtual function void   do_print(uvm_printer printer);
```

**How they work**:
- `print()` — Prints to stdout using a printer policy (table, tree, or line format).
- `sprint()` — Returns the string instead of printing.
- `convert2string()` — Override for simple `$sformatf` representation.
- `do_print()` — Override for structured printing using the printer API.

```systemverilog
virtual function string convert2string();
  return $sformatf("APB %s addr=0x%08h data=0x%08h strobe=0x%01h",
                   write ? "WR" : "RD", addr, data, strobe);
endfunction

virtual function void do_print(uvm_printer printer);
  super.do_print(printer);
  printer.print_field_int("addr",   addr,   32, UVM_HEX);
  printer.print_field_int("data",   data,   32, UVM_HEX);
  printer.print_field_int("write",  write,   1, UVM_BIN);
  printer.print_field_int("strobe", strobe,  4, UVM_HEX);
endfunction
```

**Usage**:

```systemverilog
t1.print();                          // Table format (default)
`uvm_info("DBG", t1.sprint(), UVM_HIGH)
`uvm_info("DBG", t1.convert2string(), UVM_MEDIUM)

// Change printer format
uvm_default_tree_printer tree_printer = new();
t1.print(tree_printer);
```

#### 17.4 `do_pack()` / `pack()` and `do_unpack()` / `unpack()`

**Purpose**: Serialize/deserialize an object to/from a bit stream, for scoreboarding, golden file comparison, or cross-process communication.

```systemverilog
// Method signatures:
// extern virtual function int    pack(ref bit bitstream[], input uvm_packer packer = null);
// extern virtual function int    pack_bytes(ref byte unsigned bytes[], ...);
// extern virtual function int    pack_ints(ref int unsigned ints[], ...);
// extern virtual function void   do_pack(uvm_packer packer);
//
// extern virtual function int    unpack(ref bit bitstream[], input uvm_packer packer = null);
// extern virtual function void   do_unpack(uvm_packer packer);
```

```systemverilog
virtual function void do_pack(uvm_packer packer);
  super.do_pack(packer);
  packer.pack_field_int(addr,   32);
  packer.pack_field_int(data,   32);
  packer.pack_field_int(write,   1);
  packer.pack_field_int(strobe,  4);
endfunction

virtual function void do_unpack(uvm_packer packer);
  super.do_unpack(packer);
  addr   = packer.unpack_field_int(32);
  data   = packer.unpack_field_int(32);
  write  = packer.unpack_field_int(1);
  strobe = packer.unpack_field_int(4);
endfunction
```

**Usage**:

```systemverilog
bit bitstream[];
t1.pack(bitstream);
$display("Packed %0d bits", bitstream.size());

apb_transaction t_unpacked = apb_transaction::type_id::create("t_unpacked");
t_unpacked.unpack(bitstream);
```

#### 17.5 `do_record()` / `record()`

**Purpose**: Record transactions into a waveform database for debugging in a waveform viewer.

```systemverilog
virtual function void do_record(uvm_recorder recorder);
  super.do_record(recorder);
  `uvm_record_field("addr",   addr)
  `uvm_record_field("data",   data)
  `uvm_record_field("write",  write)
  `uvm_record_field("strobe", strobe)
endfunction
```

#### 17.6 Summary Table of `uvm_object` Methods

| Public Method    | Override Method    | Purpose                        |
|------------------|--------------------|--------------------------------|
| `copy(rhs)`      | `do_copy(rhs)`     | Copy all fields from rhs       |
| `clone()`        | —                  | Create + copy (returns new obj)|
| `compare(rhs)`   | `do_compare(rhs)`  | Field-by-field equality        |
| `print(printer)`  | `do_print(printer)` | Print to stdout               |
| `sprint(printer)` | —                  | Return printed string          |
| `convert2string()`| —                  | Simple string representation   |
| `pack(bits)`      | `do_pack(packer)`  | Serialize to bits              |
| `unpack(bits)`    | `do_unpack(packer)`| Deserialize from bits          |
| `record(recorder)`| `do_record(rec)`   | Write to waveform database     |
| `create(name)`    | —                  | Factory object creation        |
| `get_type_name()` | —                  | Return class name as string    |
| `get_name()`      | —                  | Return instance name           |
| `set_name(name)`  | —                  | Set instance name              |

---

### 18. `uvm_component` — The Structural Backbone

`uvm_component` extends `uvm_object` and adds:

- **Hierarchy**: parent-child relationships forming a component tree
- **Phases**: lifecycle methods (build, connect, run, etc.)
- **Configuration**: get/set configuration from the database
- **Factory awareness**: components are created via the factory
- **Reporting**: integrated message reporting

```systemverilog
class my_component extends uvm_component;
  `uvm_component_utils(my_component)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    `uvm_info("BUILD", "Building my_component", UVM_MEDIUM)
  endfunction
endclass
```

#### Key Differences: `uvm_object` vs `uvm_component`

| Feature                | `uvm_object`                | `uvm_component`               |
|------------------------|-----------------------------|--------------------------------|
| Constructor            | `new(string name = "")`     | `new(string name, uvm_component parent)` |
| Hierarchy              | No                          | Yes — parent/children tree     |
| Factory macro          | `` `uvm_object_utils ``     | `` `uvm_component_utils ``     |
| Phases                 | No                          | Yes — build, connect, run, etc.|
| Persists across phases | No                          | Yes                            |
| Can be replaced        | During any phase            | Only during build_phase        |

#### `uvm_component` Internal Methods

```systemverilog
// Hierarchy navigation
function string            get_full_name();        // e.g. "uvm_test_top.env.agent.driver"
function uvm_component     get_parent();
function void              get_children(ref uvm_component children[$]);
function uvm_component     get_child(string name);
function int               get_num_children();
function int               get_depth();             // Depth in hierarchy

// Factory creation
function uvm_object        create_object(string type_name, string name);
function uvm_component     create_component(string type_name, string name);

// Phase control
function void              set_domain(uvm_domain domain);
function uvm_domain        get_domain();

// Configuration
function void              apply_config_settings(bit verbose = 0);
```

---

### 19. UVM Phases and the Phase Mechanism

UVM uses a phased execution model that ensures all components are built and connected before simulation begins.

#### Phase Execution Order

```
                    BUILD TIME (top-down)
                    ├── build_phase
                    ├── connect_phase
                    └── end_of_elaboration_phase

                    RUN TIME
                    ├── start_of_simulation_phase
                    ├── run_phase ←────────────────┐
                    │   (parallel with sub-phases): │
                    │   ├── reset_phase             │
                    │   ├── configure_phase         │
                    │   ├── main_phase              │ All run in parallel
                    │   ├── shutdown_phase          │
                    │   └── ...                     │
                    └──────────────────────────────┘

                    CLEANUP (bottom-up)
                    ├── extract_phase
                    ├── check_phase
                    ├── report_phase
                    └── final_phase
```

#### Phase Methods

| Phase                       | Type     | Direction  | Purpose                                 |
|-----------------------------|----------|------------|-----------------------------------------|
| `build_phase`               | Function | Top-down   | Create sub-components, configure        |
| `connect_phase`             | Function | Bottom-up  | Connect TLM ports, exports              |
| `end_of_elaboration_phase`  | Function | Bottom-up  | Final adjustments, topology display     |
| `start_of_simulation_phase` | Function | Bottom-up  | Banners, final config checks            |
| `run_phase`                 | Task     | Parallel   | Main simulation — stimulus & checking   |
| `extract_phase`             | Function | Bottom-up  | Extract results from scoreboards        |
| `check_phase`               | Function | Bottom-up  | Check for errors, compare results       |
| `report_phase`              | Function | Bottom-up  | Print summary reports                   |
| `final_phase`               | Function | Top-down   | Final cleanup                           |

#### Phase Implementation Example

```systemverilog
class my_agent extends uvm_agent;
  `uvm_component_utils(my_agent)

  my_driver    drv;
  my_monitor   mon;
  my_sequencer sqr;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (get_is_active() == UVM_ACTIVE) begin
      drv = my_driver::type_id::create("drv", this);
      sqr = my_sequencer::type_id::create("sqr", this);
    end
    mon = my_monitor::type_id::create("mon", this);
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    if (get_is_active() == UVM_ACTIVE)
      drv.seq_item_port.connect(sqr.seq_item_export);
  endfunction

  virtual task run_phase(uvm_phase phase);
    super.run_phase(phase);
    `uvm_info("RUN", "Agent run_phase started", UVM_LOW)
  endtask

  virtual function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info("REPORT", "Agent report_phase", UVM_LOW)
  endfunction
endclass
```

---

### 20. `uvm_transaction` and `uvm_sequence_item`

#### `uvm_transaction`

Extends `uvm_object` and adds timing information:

```systemverilog
// Key methods added by uvm_transaction:
// function void   accept_tr(time accept_time = 0);
// function int    begin_tr(time begin_time = 0);
// function void   end_tr(time end_time = 0, bit free_handle = 1);
// function int    get_transaction_id();
// function void   set_transaction_id(int id);
```

#### `uvm_sequence_item`

Extends `uvm_transaction` and adds sequencer awareness. **This is the class you should extend for your transaction types.**

```systemverilog
class axi_transaction extends uvm_sequence_item;
  `uvm_object_utils(axi_transaction)

  // AXI-specific fields
  rand bit [31:0]  addr;
  rand bit [31:0]  data[];
  rand bit [7:0]   len;           // Burst length - 1
  rand bit [2:0]   size;          // Bytes per beat = 2^size
  rand bit [1:0]   burst;         // FIXED=0, INCR=1, WRAP=2
  rand bit         write;
  rand bit [1:0]   resp;

  // Constraints
  constraint c_len    { len inside {[0:15]}; }
  constraint c_size   { size inside {[0:2]}; }
  constraint c_burst  { burst inside {1, 2}; }
  constraint c_data   { data.size() == len + 1; }

  function new(string name = "axi_transaction");
    super.new(name);
  endfunction

  virtual function void do_copy(uvm_object rhs);
    axi_transaction rhs_cast;
    super.do_copy(rhs);
    $cast(rhs_cast, rhs);
    this.addr  = rhs_cast.addr;
    this.data  = rhs_cast.data;
    this.len   = rhs_cast.len;
    this.size  = rhs_cast.size;
    this.burst = rhs_cast.burst;
    this.write = rhs_cast.write;
    this.resp  = rhs_cast.resp;
  endfunction

  virtual function bit do_compare(uvm_object rhs, uvm_comparer comparer);
    axi_transaction rhs_cast;
    bit status = super.do_compare(rhs, comparer);
    $cast(rhs_cast, rhs);
    status &= (this.addr  == rhs_cast.addr);
    status &= (this.data  == rhs_cast.data);   // Dynamic array comparison
    status &= (this.len   == rhs_cast.len);
    status &= (this.size  == rhs_cast.size);
    status &= (this.burst == rhs_cast.burst);
    status &= (this.write == rhs_cast.write);
    return status;
  endfunction

  virtual function string convert2string();
    string s = $sformatf("AXI %s addr=0x%08h len=%0d size=%0d burst=%0d",
                         write ? "WR" : "RD", addr, len, size, burst);
    if (write)
      foreach (data[i])
        s = {s, $sformatf("\n  data[%0d]=0x%08h", i, data[i])};
    return s;
  endfunction
endclass
```

#### Key `uvm_sequence_item` Methods

```systemverilog
// Sequencer awareness
function void        set_sequencer(uvm_sequencer_base sequencer);
function uvm_sequencer_base get_sequencer();

// Sequence awareness
function void        set_parent_sequence(uvm_sequence_base parent);
function uvm_sequence_base  get_parent_sequence();

// Response tracking
function void        set_id_info(uvm_sequence_item item);
function int         get_sequence_id();
function void        set_item_context(uvm_sequence_base parent_seq, uvm_sequencer_base sequencer);
```

---

### 21. `uvm_sequence` and `uvm_sequencer`

#### `uvm_sequence`

A sequence generates a series of sequence items and sends them to a sequencer for execution. It extends `uvm_sequence_item` so sequences can be nested.

```systemverilog
class apb_write_seq extends uvm_sequence #(apb_transaction);
  `uvm_object_utils(apb_write_seq)

  rand bit [31:0] start_addr;
  rand int        num_writes;

  constraint c_num { num_writes inside {[1:20]}; }

  function new(string name = "apb_write_seq");
    super.new(name);
  endfunction

  virtual task body();
    apb_transaction txn;

    for (int i = 0; i < num_writes; i++) begin
      txn = apb_transaction::type_id::create("txn");

      start_item(txn);          // Request grant from sequencer
      if (!txn.randomize() with {
        addr == start_addr + (i * 4);
        write == 1;
      })
        `uvm_fatal("RAND", "Randomization failed")
      finish_item(txn);         // Send to driver, wait for completion
      `uvm_info("SEQ", txn.convert2string(), UVM_HIGH)
    end
  endtask
endclass
```

#### Key `uvm_sequence` Methods

| Method | Purpose |
|--------|---------|
| `body()` | Override to define the sequence behavior |
| `start_item(item)` | Request arbitration for the item |
| `finish_item(item)` | Send item to driver, block until done |
| `start(sequencer, parent_seq, priority, call_pre_post)` | Start the sequence on a sequencer |
| `pre_body()` | Called before `body()` (if `call_pre_post` is 1) |
| `post_body()` | Called after `body()` |
| `pre_start()` | Called before `pre_body()` |
| `post_start()` | Called after `post_body()` |
| `get_response(rsp)` | Get response from driver |
| `wait_for_grant()` | Low-level: wait for sequencer grant |
| `send_request(req)` | Low-level: send request after grant |
| `wait_for_item_done()` | Low-level: wait for driver to signal done |

#### Sequence Lifecycle

```
start() called
  → pre_start()
  → pre_body()         [if call_pre_post = 1]
  → body()
    → start_item(txn)    → wait_for_grant()
    → finish_item(txn)   → send_request() + wait_for_item_done()
  → post_body()        [if call_pre_post = 1]
  → post_start()
```

#### `uvm_sequencer`

The sequencer arbitrates between multiple sequences and delivers items to the driver via a TLM port.

```systemverilog
class apb_sequencer extends uvm_sequencer #(apb_transaction);
  `uvm_component_utils(apb_sequencer)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
endclass
```

The built-in `uvm_sequencer` is parameterized and usually requires no additional customization. Its key internal mechanisms:

| Method / Property | Purpose |
|-------------------|---------|
| `seq_item_export` | TLM export that the driver connects to |
| `set_arbitration(UVM_SEQ_ARB_*)` | Set arbitration mode (FIFO, random, priority, etc.) |
| `lock(sequence)` | Grant exclusive access to a sequence |
| `unlock(sequence)` | Release exclusive access |
| `is_grabbed()` | Check if sequencer is locked |
| `stop_sequences()` | Stop all running sequences |

**Arbitration modes**:

```systemverilog
sqr.set_arbitration(UVM_SEQ_ARB_FIFO);        // Default — FIFO ordering
sqr.set_arbitration(UVM_SEQ_ARB_RANDOM);       // Random selection
sqr.set_arbitration(UVM_SEQ_ARB_STRICT_FIFO);  // Priority-based, FIFO within priority
sqr.set_arbitration(UVM_SEQ_ARB_STRICT_RANDOM); // Priority-based, random within priority
sqr.set_arbitration(UVM_SEQ_ARB_WEIGHTED);     // Weighted random
```

---

### 22. `uvm_driver`

The driver receives transactions from the sequencer and drives them onto the DUT interface.

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
      `uvm_fatal("NOVIF", "Virtual interface not found in config_db")
  endfunction

  virtual task run_phase(uvm_phase phase);
    apb_transaction txn;

    forever begin
      seq_item_port.get_next_item(txn);   // Blocking — get from sequencer
      drive_transfer(txn);
      seq_item_port.item_done();          // Signal completion to sequencer
    end
  endtask

  virtual task drive_transfer(apb_transaction txn);
    @(posedge vif.clk);
    vif.psel    <= 1'b1;
    vif.paddr   <= txn.addr;
    vif.pwrite  <= txn.write;
    if (txn.write)
      vif.pwdata <= txn.data;
    vif.penable <= 1'b0;

    @(posedge vif.clk);
    vif.penable <= 1'b1;

    @(posedge vif.clk);
    if (!txn.write)
      txn.data = vif.prdata;
    vif.psel    <= 1'b0;
    vif.penable <= 1'b0;
  endtask
endclass
```

#### Key `uvm_driver` Internal Mechanisms

| Member | Type | Purpose |
|--------|------|---------|
| `seq_item_port` | `uvm_seq_item_pull_port` | TLM port to get items from sequencer |
| `rsp_port` | `uvm_analysis_port` | Port to send responses back |
| `get_next_item(txn)` | Via port | Blocking — gets next transaction |
| `try_next_item(txn)` | Via port | Non-blocking — returns null if nothing available |
| `item_done(rsp)` | Via port | Signal completion, optional response |
| `put(rsp)` | Via rsp_port | Explicit response via analysis port |

#### Driver with Response

```systemverilog
virtual task run_phase(uvm_phase phase);
  apb_transaction req, rsp;

  forever begin
    seq_item_port.get_next_item(req);
    drive_transfer(req);

    // Create and send response
    rsp = apb_transaction::type_id::create("rsp");
    rsp.set_id_info(req);    // Copy sequence/transaction IDs
    rsp.addr  = req.addr;
    rsp.data  = req.data;
    rsp.resp  = 2'b00;       // OKAY
    seq_item_port.item_done(rsp);
  end
endtask
```

---

### 23. `uvm_monitor`

The monitor passively observes DUT interface signals, reconstructs transactions, and broadcasts them via analysis ports.

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
      `uvm_fatal("NOVIF", "Virtual interface not found")
  endfunction

  virtual task run_phase(uvm_phase phase);
    forever begin
      apb_transaction txn;
      collect_transaction(txn);
      ap.write(txn);                // Broadcast to all subscribers
    end
  endtask

  virtual task collect_transaction(output apb_transaction txn);
    txn = apb_transaction::type_id::create("mon_txn");

    @(posedge vif.clk iff vif.psel && !vif.penable);
    txn.addr  = vif.paddr;
    txn.write = vif.pwrite;
    if (txn.write)
      txn.data = vif.pwdata;

    @(posedge vif.clk iff vif.penable);
    if (!txn.write)
      txn.data = vif.prdata;

    txn.accept_tr();
    `uvm_info("MON", txn.convert2string(), UVM_HIGH)
  endtask
endclass
```

#### Analysis Port Broadcasting

The `uvm_analysis_port` uses a publish-subscribe pattern:
- The monitor **writes** a transaction once.
- Multiple subscribers receive it simultaneously (zero-time broadcast).
- Subscribers implement `uvm_analysis_imp` or connect through `uvm_tlm_analysis_fifo`.

---

### 24. `uvm_agent`

The agent is a container that groups a driver, monitor, and sequencer for a single protocol interface. It can operate in **active** mode (drives stimulus) or **passive** mode (only monitors).

```systemverilog
class apb_agent extends uvm_agent;
  `uvm_component_utils(apb_agent)

  apb_driver    drv;
  apb_monitor   mon;
  apb_sequencer sqr;

  uvm_analysis_port #(apb_transaction) ap;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    mon = apb_monitor::type_id::create("mon", this);
    ap  = new("ap", this);

    if (get_is_active() == UVM_ACTIVE) begin
      drv = apb_driver::type_id::create("drv", this);
      sqr = apb_sequencer::type_id::create("sqr", this);
    end
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);

    mon.ap.connect(ap);   // Forward monitor's analysis port

    if (get_is_active() == UVM_ACTIVE)
      drv.seq_item_port.connect(sqr.seq_item_export);
  endfunction
endclass
```

#### Key `uvm_agent` Methods

| Method | Purpose |
|--------|---------|
| `get_is_active()` | Returns `UVM_ACTIVE` or `UVM_PASSIVE` |
| `set_is_active()` | Set active/passive (typically via config_db) |

**Setting agent mode from the test**:

```systemverilog
uvm_config_db #(uvm_active_passive_enum)::set(
  this, "env.agent", "is_active", UVM_PASSIVE);
```

---

### 25. `uvm_scoreboard`

The scoreboard collects transactions from monitors, computes expected results, and checks actual vs expected.

```systemverilog
class apb_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(apb_scoreboard)

  uvm_analysis_imp #(apb_transaction, apb_scoreboard) ap_imp;

  // Reference model — a simple memory
  bit [31:0] mem [bit [31:0]];
  int num_writes;
  int num_reads;
  int num_errors;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ap_imp = new("ap_imp", this);
  endfunction

  // Called by analysis port when monitor broadcasts a transaction
  virtual function void write(apb_transaction txn);
    if (txn.write) begin
      mem[txn.addr] = txn.data;
      num_writes++;
      `uvm_info("SCB", $sformatf("WRITE: addr=0x%08h data=0x%08h",
                txn.addr, txn.data), UVM_HIGH)
    end else begin
      num_reads++;
      if (mem.exists(txn.addr)) begin
        if (txn.data !== mem[txn.addr]) begin
          num_errors++;
          `uvm_error("SCB", $sformatf(
            "READ MISMATCH: addr=0x%08h expected=0x%08h got=0x%08h",
            txn.addr, mem[txn.addr], txn.data))
        end else begin
          `uvm_info("SCB", $sformatf("READ MATCH: addr=0x%08h data=0x%08h",
                    txn.addr, txn.data), UVM_HIGH)
        end
      end else begin
        `uvm_warning("SCB", $sformatf("READ from uninitialized addr=0x%08h", txn.addr))
      end
    end
  endfunction

  virtual function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info("SCB", $sformatf(
      "\n=== Scoreboard Summary ===\nWrites: %0d\nReads: %0d\nErrors: %0d\n",
      num_writes, num_reads, num_errors), UVM_LOW)

    if (num_errors > 0)
      `uvm_error("SCB", "TEST FAILED — mismatches detected")
    else
      `uvm_info("SCB", "TEST PASSED — all checks passed", UVM_LOW)
  endfunction
endclass
```

#### Multiple Analysis Ports with `uvm_analysis_imp_decl`

When a scoreboard receives from multiple sources, use the declaration macro:

```systemverilog
`uvm_analysis_imp_decl(_expected)
`uvm_analysis_imp_decl(_actual)

class dual_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(dual_scoreboard)

  uvm_analysis_imp_expected #(apb_transaction, dual_scoreboard) expected_imp;
  uvm_analysis_imp_actual   #(apb_transaction, dual_scoreboard) actual_imp;

  apb_transaction expected_q[$];

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    expected_imp = new("expected_imp", this);
    actual_imp   = new("actual_imp", this);
  endfunction

  function void write_expected(apb_transaction txn);
    expected_q.push_back(txn);
  endfunction

  function void write_actual(apb_transaction txn);
    apb_transaction exp;
    if (expected_q.size() == 0) begin
      `uvm_error("SCB", "Unexpected transaction received")
      return;
    end
    exp = expected_q.pop_front();
    if (!txn.compare(exp))
      `uvm_error("SCB", {"Mismatch:\n  Expected: ", exp.convert2string(),
                          "\n  Actual:   ", txn.convert2string()})
  endfunction
endclass
```

---

### 26. `uvm_env`

The environment is a container that assembles agents, scoreboards, and other sub-environments into a coherent verification hierarchy.

```systemverilog
class apb_env extends uvm_env;
  `uvm_component_utils(apb_env)

  apb_agent       agent;
  apb_scoreboard  scoreboard;

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
    agent.ap.connect(scoreboard.ap_imp);
  endfunction
endclass
```

#### Multi-Protocol Environment

```systemverilog
class soc_env extends uvm_env;
  `uvm_component_utils(soc_env)

  apb_env          apb;
  axi_env          axi;
  spi_env          spi;
  soc_scoreboard   scb;
  soc_coverage     cov;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    apb = apb_env::type_id::create("apb", this);
    axi = axi_env::type_id::create("axi", this);
    spi = spi_env::type_id::create("spi", this);
    scb = soc_scoreboard::type_id::create("scb", this);
    cov = soc_coverage::type_id::create("cov", this);
  endfunction
endclass
```

---

### 27. `uvm_test`

The test is the top-level component. It creates the environment and launches sequences.

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

    // Pass virtual interface down
    uvm_config_db #(virtual apb_if)::set(this, "env.agent.*", "vif", tb_top.apb_vif);
  endfunction

  virtual function void end_of_elaboration_phase(uvm_phase phase);
    super.end_of_elaboration_phase(phase);
    uvm_top.print_topology();   // Print the component tree
  endfunction

  virtual task run_phase(uvm_phase phase);
    phase.raise_objection(this, "Test running");
    #100;
    phase.drop_objection(this, "Test done");
  endtask
endclass
```

#### Extending the Base Test

```systemverilog
class apb_write_test extends apb_base_test;
  `uvm_component_utils(apb_write_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual task run_phase(uvm_phase phase);
    apb_write_seq seq = apb_write_seq::type_id::create("seq");

    phase.raise_objection(this, "Running write test");

    seq.start_addr  = 32'h0000_1000;
    seq.num_writes  = 10;
    seq.start(env.agent.sqr);   // Start sequence on sequencer

    #100;
    phase.drop_objection(this, "Write test done");
  endtask
endclass

class apb_read_after_write_test extends apb_base_test;
  `uvm_component_utils(apb_read_after_write_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual task run_phase(uvm_phase phase);
    apb_write_seq wr_seq = apb_write_seq::type_id::create("wr_seq");
    apb_read_seq  rd_seq = apb_read_seq::type_id::create("rd_seq");

    phase.raise_objection(this);

    wr_seq.start_addr = 32'h2000;
    wr_seq.num_writes = 5;
    wr_seq.start(env.agent.sqr);

    rd_seq.start_addr = 32'h2000;
    rd_seq.num_reads  = 5;
    rd_seq.start(env.agent.sqr);

    phase.drop_objection(this);
  endtask
endclass
```

**Running a specific test from the command line**:

```bash
vsim +UVM_TESTNAME=apb_write_test
# or
vcs ... +UVM_TESTNAME=apb_read_after_write_test
```

---

## Part 3 — UVM Infrastructure and Advanced Topics

---

### 28. The UVM Factory

The factory is UVM's mechanism for creating objects and components with the ability to override types without modifying existing code.

#### Registration

```systemverilog
// For uvm_object subclasses:
class my_txn extends uvm_sequence_item;
  `uvm_object_utils(my_txn)
  // ...
endclass

// For uvm_component subclasses:
class my_driver extends uvm_driver #(my_txn);
  `uvm_component_utils(my_driver)
  // ...
endclass

// With field automation (optional):
class my_txn extends uvm_sequence_item;
  `uvm_object_utils_begin(my_txn)
    `uvm_field_int(addr, UVM_ALL_ON)
    `uvm_field_int(data, UVM_ALL_ON)
  `uvm_object_utils_end
  // ...
endclass
```

#### Factory Creation

Always create objects and components via the factory, never with plain `new()`:

```systemverilog
// Object creation
my_txn txn = my_txn::type_id::create("txn");

// Component creation (requires parent)
my_driver drv = my_driver::type_id::create("drv", this);
```

#### Type Overrides

Replace one type with another globally or per-instance:

```systemverilog
class improved_txn extends my_txn;
  `uvm_object_utils(improved_txn)
  // Additional fields or different constraints
  rand bit [7:0] qos;
endclass

class improved_driver extends my_driver;
  `uvm_component_utils(improved_driver)
  // Additional or modified drive logic
endclass
```

```systemverilog
// In a test's build_phase:
virtual function void build_phase(uvm_phase phase);
  super.build_phase(phase);

  // Global type override: all my_txn creations return improved_txn
  my_txn::type_id::set_type_override(improved_txn::get_type());

  // Instance override: only the driver in env.agent is replaced
  my_driver::type_id::set_inst_override(
    improved_driver::get_type(), "env.agent.drv", this);

  env = my_env::type_id::create("env", this);
endfunction
```

#### Factory Debug

```systemverilog
// Print all registered types and active overrides
factory.print();

// Or from command line
+UVM_VERBOSITY=UVM_DEBUG
```

---

### 29. Configuration Database (`uvm_config_db`)

The configuration database allows hierarchical parameterization of the testbench without hard-coding values.

#### API

```systemverilog
// Set a value
uvm_config_db #(TYPE)::set(
  uvm_component cntxt,    // Context (typically 'this' or null)
  string        inst_name, // Hierarchical path glob pattern
  string        field_name,// Field identifier
  TYPE          value      // Value to store
);

// Get a value
bit success = uvm_config_db #(TYPE)::get(
  uvm_component cntxt,
  string        inst_name,
  string        field_name,
  ref TYPE      value      // Output — populated if found
);
```

#### Common Patterns

```systemverilog
// In the top-level test — set virtual interface
class my_test extends uvm_test;
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Pass interface to all components under env.agent
    uvm_config_db #(virtual apb_if)::set(
      this, "env.agent.*", "vif", tb_top.apb_vif);

    // Set agent to passive mode
    uvm_config_db #(uvm_active_passive_enum)::set(
      this, "env.agent", "is_active", UVM_PASSIVE);

    // Pass integer configuration
    uvm_config_db #(int)::set(
      this, "env.agent.drv", "max_retries", 5);

    // Pass a configuration object
    my_config cfg = my_config::type_id::create("cfg");
    cfg.num_transactions = 100;
    cfg.enable_coverage  = 1;
    uvm_config_db #(my_config)::set(this, "env", "cfg", cfg);

    env = my_env::type_id::create("env", this);
  endfunction
endclass

// In a component — retrieve configuration
class my_driver extends uvm_driver #(apb_transaction);
  virtual apb_if vif;
  int max_retries = 3;

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    if (!uvm_config_db #(virtual apb_if)::get(this, "", "vif", vif))
      `uvm_fatal("CFG", "Virtual interface not found")

    // Optional config — use default if not set
    void'(uvm_config_db #(int)::get(this, "", "max_retries", max_retries));
  endfunction
endclass
```

#### Path Matching

The `inst_name` argument supports glob patterns:

| Pattern | Meaning |
|---------|---------|
| `""` | Apply to the context component itself |
| `"*"` | Apply to all direct children |
| `"env.*"` | Apply to env and all its descendants |
| `"env.agent.drv"` | Apply to a specific component |
| `"env.*.drv"` | Apply to any agent's driver in env |

#### Config Debug

```systemverilog
// From command line
+UVM_CONFIG_DB_TRACE

// Programmatic
uvm_config_db #(virtual apb_if)::dump();
```

---

### 30. Field Automation Macros (`uvm_field_*`)

Field automation macros generate default implementations of `copy`, `compare`, `print`, `pack`, `unpack`, and `record` for registered fields.

```systemverilog
class my_txn extends uvm_sequence_item;
  rand bit [31:0] addr;
  rand bit [31:0] data;
  rand bit        write;
  string          label;
  bit [7:0]       payload[];

  `uvm_object_utils_begin(my_txn)
    `uvm_field_int(addr,     UVM_ALL_ON | UVM_HEX)
    `uvm_field_int(data,     UVM_ALL_ON | UVM_HEX)
    `uvm_field_int(write,    UVM_ALL_ON | UVM_BIN)
    `uvm_field_string(label, UVM_ALL_ON)
    `uvm_field_array_int(payload, UVM_ALL_ON)
  `uvm_object_utils_end

  function new(string name = "my_txn");
    super.new(name);
  endfunction
endclass
```

#### Available Field Macros

| Macro | Used For |
|-------|----------|
| `` `uvm_field_int `` | Integral types (bit, logic, int, etc.) |
| `` `uvm_field_string `` | Strings |
| `` `uvm_field_object `` | `uvm_object` sub-objects |
| `` `uvm_field_enum `` | Enumerated types |
| `` `uvm_field_real `` | Real/shortreal |
| `` `uvm_field_event `` | Events |
| `` `uvm_field_array_int `` | Dynamic arrays of integrals |
| `` `uvm_field_array_string `` | Dynamic arrays of strings |
| `` `uvm_field_array_object `` | Dynamic arrays of objects |
| `` `uvm_field_queue_int `` | Queues of integrals |
| `` `uvm_field_queue_string `` | Queues of strings |
| `` `uvm_field_queue_object `` | Queues of objects |
| `` `uvm_field_sarray_int `` | Static arrays of integrals |
| `` `uvm_field_aa_int_string `` | Associative arrays (int indexed by string) |

#### Flag Constants

| Flag | Effect |
|------|--------|
| `UVM_ALL_ON` | Enable all operations |
| `UVM_NOPRINT` | Exclude from print |
| `UVM_NOCOMPARE` | Exclude from compare |
| `UVM_NOCOPY` | Exclude from copy |
| `UVM_NOPACK` | Exclude from pack/unpack |
| `UVM_NORECORD` | Exclude from record |
| `UVM_HEX` | Print in hexadecimal |
| `UVM_DEC` | Print in decimal |
| `UVM_BIN` | Print in binary |
| `UVM_UNSIGNED` | Print as unsigned |
| `UVM_DEFAULT` | Same as `UVM_ALL_ON` |

#### Field Automation vs Manual `do_*` Methods

| Aspect | Field Macros | Manual `do_*` |
|--------|-------------|---------------|
| Code volume | Minimal | More code |
| Performance | Slower (macro overhead) | Faster |
| Flexibility | Limited | Full control |
| Debug | Harder to trace | Easier to debug |
| Recommendation | Prototyping, simple objects | Production, performance-critical |

**Best practice**: Use manual `do_copy`, `do_compare`, `do_print`, etc. for production code and field macros for quick prototyping.

---

### 31. TLM Ports and Communication

UVM uses Transaction Level Modeling (TLM) for inter-component communication. TLM decouples components — they communicate through standardized interfaces without knowing each other's implementation.

#### TLM Port Types

| Port Type | Direction | Blocking? | 1-to-many? |
|-----------|-----------|-----------|------------|
| `uvm_blocking_put_port` | Producer → Consumer | Yes | No |
| `uvm_nonblocking_put_port` | Producer → Consumer | No | No |
| `uvm_blocking_get_port` | Consumer ← Producer | Yes | No |
| `uvm_analysis_port` | Publisher → Subscribers | No (function) | Yes |
| `uvm_seq_item_pull_port` | Driver ← Sequencer | Yes | No |

#### Analysis Port Pattern (Most Common)

```systemverilog
// In the monitor (publisher)
class my_monitor extends uvm_monitor;
  uvm_analysis_port #(my_txn) ap;

  function void build_phase(uvm_phase phase);
    ap = new("ap", this);
  endfunction

  task run_phase(uvm_phase phase);
    forever begin
      my_txn txn = collect();
      ap.write(txn);     // Broadcast — calls write() on all subscribers
    end
  endtask
endclass

// In the scoreboard (subscriber)
class my_scoreboard extends uvm_scoreboard;
  uvm_analysis_imp #(my_txn, my_scoreboard) imp;

  function void build_phase(uvm_phase phase);
    imp = new("imp", this);
  endfunction

  function void write(my_txn txn);
    // Process received transaction
  endfunction
endclass

// Connection (in env's connect_phase)
monitor.ap.connect(scoreboard.imp);
```

#### TLM FIFO

When the subscriber needs to process transactions at its own pace (not in zero time), use a `uvm_tlm_analysis_fifo`:

```systemverilog
class my_checker extends uvm_component;
  `uvm_component_utils(my_checker)

  uvm_tlm_analysis_fifo #(my_txn) fifo;
  uvm_analysis_export #(my_txn)   analysis_export;

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    fifo = new("fifo", this);
    analysis_export = new("analysis_export", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    analysis_export.connect(fifo.analysis_export);
  endfunction

  task run_phase(uvm_phase phase);
    my_txn txn;
    forever begin
      fifo.get(txn);        // Blocking get — waits for data
      process_txn(txn);
    end
  endtask
endclass
```

---

### 32. UVM Reporting and Messaging

UVM provides a unified reporting infrastructure with severity levels, verbosity control, and customizable actions.

#### Messaging Macros

```systemverilog
`uvm_info   ("TAG", "message string", UVM_MEDIUM)  // Informational
`uvm_warning("TAG", "message string")               // Warning
`uvm_error  ("TAG", "message string")               // Error (non-fatal by default)
`uvm_fatal  ("TAG", "message string")               // Fatal — stops simulation
```

#### Verbosity Levels

| Level | Value | Description |
|-------|-------|-------------|
| `UVM_NONE` | 0 | Always displayed |
| `UVM_LOW` | 100 | Low detail — important milestones |
| `UVM_MEDIUM` | 200 | Medium detail — default |
| `UVM_HIGH` | 300 | High detail — debugging |
| `UVM_FULL` | 400 | Full detail — everything |
| `UVM_DEBUG` | 500 | Debug only |

**Command-line control**:

```bash
+UVM_VERBOSITY=UVM_HIGH
```

**Programmatic control**:

```systemverilog
set_report_verbosity_level(UVM_HIGH);

// Per-ID verbosity
set_report_verbosity_level_hier(UVM_DEBUG);
set_report_id_verbosity("MON", UVM_FULL);
```

#### Severity Actions

| Action | Description |
|--------|-------------|
| `UVM_NO_ACTION` | Ignore |
| `UVM_DISPLAY` | Print to stdout |
| `UVM_LOG` | Write to log file |
| `UVM_COUNT` | Count towards max quit count |
| `UVM_EXIT` | Exit simulation |
| `UVM_CALL_HOOK` | Call report hook |
| `UVM_STOP` | Stop simulation ($stop) |

```systemverilog
// Promote warnings to errors for a specific ID
set_report_severity_id_action(UVM_WARNING, "CFG", UVM_ERROR);

// Set max error count before simulation stops
set_report_max_quit_count(10);

// Demote errors to warnings
set_report_severity_id_override(UVM_ERROR, "EXPECTED_ERR", UVM_WARNING);
```

---

### 33. Objection Mechanism

Objections control when the `run_phase` (and its sub-phases) end. The phase continues as long as any component has a raised objection.

```systemverilog
class my_test extends uvm_test;
  virtual task run_phase(uvm_phase phase);
    phase.raise_objection(this, "Starting test");

    // Run stimulus
    my_seq seq = my_seq::type_id::create("seq");
    seq.start(env.agent.sqr);

    // Drain time — wait for DUT pipeline to flush
    #1000;

    phase.drop_objection(this, "Test complete");
  endtask
endclass
```

#### Objection Rules

1. **Raise before starting stimulus**, drop after all expected responses are received.
2. The phase ends when all objections are dropped (objection count reaches 0).
3. A **drain time** can be set globally:

```systemverilog
uvm_objection obj = phase.get_objection();
obj.set_drain_time(this, 500ns);
```

4. Objections can be raised/dropped from sequences too:

```systemverilog
class my_seq extends uvm_sequence #(my_txn);
  virtual task body();
    uvm_phase phase = get_starting_phase();
    if (phase != null)
      phase.raise_objection(this);

    // Generate transactions
    repeat (10) begin
      my_txn txn = my_txn::type_id::create("txn");
      start_item(txn);
      txn.randomize();
      finish_item(txn);
    end

    if (phase != null)
      phase.drop_objection(this);
  endtask
endclass
```

#### Objection Debug

```bash
+UVM_OBJECTION_TRACE
```

---

### 34. UVM Register Layer (RAL) Overview

The Register Abstraction Layer provides a mirror of the DUT's register map in the testbench, enabling register-level stimulus and checking.

#### RAL Class Hierarchy

```
uvm_reg_block
├── uvm_reg (individual register)
│   └── uvm_reg_field (fields within a register)
├── uvm_mem (memories)
└── uvm_reg_map (address map)
```

#### Register Definition

```systemverilog
class ctrl_reg extends uvm_reg;
  `uvm_object_utils(ctrl_reg)

  rand uvm_reg_field enable;
  rand uvm_reg_field mode;
  rand uvm_reg_field irq_mask;

  function new(string name = "ctrl_reg");
    super.new(name, 32, UVM_NO_COVERAGE);   // 32-bit register
  endfunction

  virtual function void build();
    enable   = uvm_reg_field::type_id::create("enable");
    mode     = uvm_reg_field::type_id::create("mode");
    irq_mask = uvm_reg_field::type_id::create("irq_mask");

    //           parent, size, lsb, access, volatile, reset, has_reset, is_rand, individual access
    enable.configure  (this, 1,  0, "RW", 0, 1'h0, 1, 1, 0);
    mode.configure    (this, 2,  1, "RW", 0, 2'h0, 1, 1, 0);
    irq_mask.configure(this, 8,  8, "RW", 0, 8'h0, 1, 1, 0);
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

    busy.configure      (this, 1, 0, "RO", 1, 1'h0, 1, 0, 0);
    error.configure     (this, 1, 1, "RO", 1, 1'h0, 1, 0, 0);
    irq_status.configure(this, 8, 8, "W1C", 1, 8'h0, 1, 0, 0);
  endfunction
endclass
```

#### Register Block

```systemverilog
class my_reg_block extends uvm_reg_block;
  `uvm_object_utils(my_reg_block)

  rand ctrl_reg   ctrl;
  rand status_reg status;

  uvm_reg_map default_map;

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

#### RAL Access Methods

```systemverilog
// In a sequence or test
task body();
  uvm_status_e status;
  uvm_reg_data_t data;

  // Write via register model (front-door — goes through bus agent)
  reg_block.ctrl.write(status, 32'h0000_0301);

  // Read via register model
  reg_block.status.read(status, data);
  `uvm_info("RAL", $sformatf("Status = 0x%08h", data), UVM_LOW)

  // Read a specific field
  data = reg_block.ctrl.enable.get();

  // Mirror check — read from DUT and compare with model
  reg_block.ctrl.mirror(status, UVM_CHECK);

  // Backdoor access — bypasses bus, directly peeks/pokes DUT signals
  reg_block.ctrl.poke(status, 32'h0000_0001);
  reg_block.status.peek(status, data);
endtask
```

---

### 35. Virtual Sequences and Virtual Sequencers

Virtual sequences coordinate multiple sequences across different agents/protocols.

#### Virtual Sequencer

```systemverilog
class soc_virtual_sequencer extends uvm_sequencer;
  `uvm_component_utils(soc_virtual_sequencer)

  apb_sequencer apb_sqr;
  axi_sequencer axi_sqr;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
endclass
```

#### Virtual Sequence

```systemverilog
class soc_init_sequence extends uvm_sequence;
  `uvm_object_utils(soc_init_sequence)
  `uvm_declare_p_sequencer(soc_virtual_sequencer)

  function new(string name = "soc_init_sequence");
    super.new(name);
  endfunction

  virtual task body();
    apb_config_seq  apb_seq = apb_config_seq::type_id::create("apb_seq");
    axi_burst_seq   axi_seq = axi_burst_seq::type_id::create("axi_seq");

    // Configure device via APB first
    apb_seq.start(p_sequencer.apb_sqr);

    // Then start AXI data transfer
    fork
      axi_seq.start(p_sequencer.axi_sqr);
    join
  endtask
endclass
```

#### Connecting in the Environment

```systemverilog
class soc_env extends uvm_env;
  apb_agent               apb_agt;
  axi_agent               axi_agt;
  soc_virtual_sequencer   v_sqr;

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    v_sqr.apb_sqr = apb_agt.sqr;
    v_sqr.axi_sqr = axi_agt.sqr;
  endfunction
endclass
```

---

### 36. Coverage-Driven Verification with UVM

#### Functional Coverage in a Subscriber

```systemverilog
class apb_coverage extends uvm_subscriber #(apb_transaction);
  `uvm_component_utils(apb_coverage)

  apb_transaction txn;

  covergroup apb_cg;
    option.per_instance = 1;

    addr_cp: coverpoint txn.addr {
      bins low    = {[32'h0000:32'h0FFF]};
      bins mid    = {[32'h1000:32'h7FFF]};
      bins high   = {[32'h8000:32'hFFFF]};
    }

    write_cp: coverpoint txn.write {
      bins read  = {0};
      bins write = {1};
    }

    data_cp: coverpoint txn.data {
      bins zero     = {0};
      bins non_zero = {[1:$]};
      bins all_ones = {32'hFFFF_FFFF};
    }

    addr_x_write: cross addr_cp, write_cp;
  endgroup

  function new(string name, uvm_component parent);
    super.new(name, parent);
    apb_cg = new();
  endfunction

  virtual function void write(apb_transaction t);
    txn = t;
    apb_cg.sample();
  endfunction

  virtual function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info("COV", $sformatf("Coverage: %.2f%%", apb_cg.get_coverage()), UVM_LOW)
  endfunction
endclass
```

#### Connecting Coverage

```systemverilog
class apb_env extends uvm_env;
  apb_agent     agent;
  apb_scoreboard scb;
  apb_coverage   cov;

  virtual function void connect_phase(uvm_phase phase);
    agent.ap.connect(scb.ap_imp);
    agent.ap.connect(cov.analysis_export);  // uvm_subscriber has this built in
  endfunction
endclass
```

---

### 37. Complete UVM Testbench Example

This section ties everything together with a complete, working APB testbench.

#### Interface Definition

```systemverilog
interface apb_if(input logic clk, input logic rst_n);
  logic        psel;
  logic        penable;
  logic [31:0] paddr;
  logic        pwrite;
  logic [31:0] pwdata;
  logic [31:0] prdata;
  logic        pready;
  logic        pslverr;

  modport master(
    output psel, penable, paddr, pwrite, pwdata,
    input  prdata, pready, pslverr
  );

  modport slave(
    input  psel, penable, paddr, pwrite, pwdata,
    output prdata, pready, pslverr
  );
endinterface
```

#### Transaction

```systemverilog
class apb_transaction extends uvm_sequence_item;
  `uvm_object_utils(apb_transaction)

  rand bit [31:0] addr;
  rand bit [31:0] data;
  rand bit        write;
  bit             slverr;

  constraint c_addr_align { addr[1:0] == 2'b00; }

  function new(string name = "apb_transaction");
    super.new(name);
  endfunction

  virtual function void do_copy(uvm_object rhs);
    apb_transaction t;
    super.do_copy(rhs);
    $cast(t, rhs);
    addr   = t.addr;
    data   = t.data;
    write  = t.write;
    slverr = t.slverr;
  endfunction

  virtual function bit do_compare(uvm_object rhs, uvm_comparer comparer);
    apb_transaction t;
    bit status = super.do_compare(rhs, comparer);
    $cast(t, rhs);
    status &= (addr   == t.addr);
    status &= (data   == t.data);
    status &= (write  == t.write);
    return status;
  endfunction

  virtual function string convert2string();
    return $sformatf("APB %s addr=0x%08h data=0x%08h%s",
                     write ? "WR" : "RD", addr, data,
                     slverr ? " SLVERR" : "");
  endfunction

  virtual function void do_print(uvm_printer printer);
    super.do_print(printer);
    printer.print_field_int("addr",   addr,   32, UVM_HEX);
    printer.print_field_int("data",   data,   32, UVM_HEX);
    printer.print_field_int("write",  write,   1, UVM_BIN);
    printer.print_field_int("slverr", slverr,  1, UVM_BIN);
  endfunction
endclass
```

#### Sequences

```systemverilog
class apb_base_seq extends uvm_sequence #(apb_transaction);
  `uvm_object_utils(apb_base_seq)

  function new(string name = "apb_base_seq");
    super.new(name);
  endfunction
endclass

class apb_write_seq extends apb_base_seq;
  `uvm_object_utils(apb_write_seq)

  rand bit [31:0] start_addr;
  rand int unsigned num_writes;

  constraint c_num { num_writes inside {[1:32]}; }

  function new(string name = "apb_write_seq");
    super.new(name);
  endfunction

  virtual task body();
    apb_transaction txn;
    for (int i = 0; i < num_writes; i++) begin
      txn = apb_transaction::type_id::create("txn");
      start_item(txn);
      if (!txn.randomize() with {
        addr  == local::start_addr + (i * 4);
        write == 1;
      })
        `uvm_fatal("RAND", "Randomization failed")
      finish_item(txn);
      `uvm_info("SEQ", txn.convert2string(), UVM_HIGH)
    end
  endtask
endclass

class apb_read_seq extends apb_base_seq;
  `uvm_object_utils(apb_read_seq)

  rand bit [31:0] start_addr;
  rand int unsigned num_reads;

  constraint c_num { num_reads inside {[1:32]}; }

  function new(string name = "apb_read_seq");
    super.new(name);
  endfunction

  virtual task body();
    apb_transaction txn;
    for (int i = 0; i < num_reads; i++) begin
      txn = apb_transaction::type_id::create("txn");
      start_item(txn);
      if (!txn.randomize() with {
        addr  == local::start_addr + (i * 4);
        write == 0;
      })
        `uvm_fatal("RAND", "Randomization failed")
      finish_item(txn);
      `uvm_info("SEQ", txn.convert2string(), UVM_HIGH)
    end
  endtask
endclass

class apb_write_read_seq extends apb_base_seq;
  `uvm_object_utils(apb_write_read_seq)

  function new(string name = "apb_write_read_seq");
    super.new(name);
  endfunction

  virtual task body();
    apb_write_seq wr_seq = apb_write_seq::type_id::create("wr_seq");
    apb_read_seq  rd_seq = apb_read_seq::type_id::create("rd_seq");

    wr_seq.start_addr = 32'h0000_0000;
    wr_seq.num_writes = 8;
    wr_seq.start(m_sequencer);

    rd_seq.start_addr = 32'h0000_0000;
    rd_seq.num_reads  = 8;
    rd_seq.start(m_sequencer);
  endtask
endclass
```

#### Driver

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
      `uvm_fatal("DRV", "No virtual interface found")
  endfunction

  virtual task run_phase(uvm_phase phase);
    vif.psel    <= 0;
    vif.penable <= 0;

    forever begin
      apb_transaction txn;
      seq_item_port.get_next_item(txn);
      drive(txn);
      seq_item_port.item_done();
    end
  endtask

  virtual task drive(apb_transaction txn);
    // Setup phase
    @(posedge vif.clk);
    vif.psel   <= 1;
    vif.paddr  <= txn.addr;
    vif.pwrite <= txn.write;
    if (txn.write)
      vif.pwdata <= txn.data;
    vif.penable <= 0;

    // Access phase
    @(posedge vif.clk);
    vif.penable <= 1;

    // Wait for ready
    do @(posedge vif.clk);
    while (!vif.pready);

    if (!txn.write)
      txn.data = vif.prdata;
    txn.slverr = vif.pslverr;

    // Idle
    vif.psel    <= 0;
    vif.penable <= 0;
  endtask
endclass
```

#### Monitor

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
      `uvm_fatal("MON", "No virtual interface found")
  endfunction

  virtual task run_phase(uvm_phase phase);
    forever begin
      apb_transaction txn = apb_transaction::type_id::create("txn");

      // Wait for setup phase
      @(posedge vif.clk iff (vif.psel && !vif.penable));
      txn.addr  = vif.paddr;
      txn.write = vif.pwrite;
      if (txn.write)
        txn.data = vif.pwdata;

      // Wait for access phase completion
      @(posedge vif.clk iff (vif.penable && vif.pready));
      if (!txn.write)
        txn.data = vif.prdata;
      txn.slverr = vif.pslverr;

      `uvm_info("MON", txn.convert2string(), UVM_HIGH)
      ap.write(txn);
    end
  endtask
endclass
```

#### Agent, Scoreboard, Coverage, Environment, Test

```systemverilog
// ──── Sequencer ────
typedef uvm_sequencer #(apb_transaction) apb_sequencer;

// ──── Agent ────
class apb_agent extends uvm_agent;
  `uvm_component_utils(apb_agent)

  apb_driver     drv;
  apb_monitor    mon;
  apb_sequencer  sqr;

  uvm_analysis_port #(apb_transaction) ap;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    mon = apb_monitor::type_id::create("mon", this);
    ap  = new("ap", this);
    if (get_is_active() == UVM_ACTIVE) begin
      drv = apb_driver::type_id::create("drv", this);
      sqr = apb_sequencer::type_id::create("sqr", this);
    end
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    mon.ap.connect(ap);
    if (get_is_active() == UVM_ACTIVE)
      drv.seq_item_port.connect(sqr.seq_item_export);
  endfunction
endclass

// ──── Scoreboard ────
class apb_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(apb_scoreboard)

  uvm_analysis_imp #(apb_transaction, apb_scoreboard) imp;
  bit [31:0] mem [bit [31:0]];
  int writes, reads, errors;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    imp = new("imp", this);
  endfunction

  virtual function void write(apb_transaction txn);
    if (txn.write) begin
      mem[txn.addr] = txn.data;
      writes++;
    end else begin
      reads++;
      if (mem.exists(txn.addr)) begin
        if (txn.data !== mem[txn.addr]) begin
          errors++;
          `uvm_error("SCB", $sformatf("MISMATCH addr=0x%08h exp=0x%08h got=0x%08h",
                     txn.addr, mem[txn.addr], txn.data))
        end
      end
    end
  endfunction

  virtual function void report_phase(uvm_phase phase);
    `uvm_info("SCB", $sformatf("Writes=%0d Reads=%0d Errors=%0d", writes, reads, errors), UVM_LOW)
    if (errors == 0)
      `uvm_info("SCB", "** TEST PASSED **", UVM_NONE)
    else
      `uvm_error("SCB", "** TEST FAILED **")
  endfunction
endclass

// ──── Coverage ────
class apb_coverage extends uvm_subscriber #(apb_transaction);
  `uvm_component_utils(apb_coverage)

  apb_transaction txn;

  covergroup apb_cg;
    addr_cp:  coverpoint txn.addr[15:0]  { bins b[] = {[0:$]}; option.auto_bin_max = 16; }
    write_cp: coverpoint txn.write       { bins rd = {0}; bins wr = {1}; }
    cross_cp: cross addr_cp, write_cp;
  endgroup

  function new(string name, uvm_component parent);
    super.new(name, parent);
    apb_cg = new();
  endfunction

  virtual function void write(apb_transaction t);
    txn = t;
    apb_cg.sample();
  endfunction
endclass

// ──── Environment ────
class apb_env extends uvm_env;
  `uvm_component_utils(apb_env)

  apb_agent      agent;
  apb_scoreboard scb;
  apb_coverage   cov;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    agent = apb_agent::type_id::create("agent", this);
    scb   = apb_scoreboard::type_id::create("scb", this);
    cov   = apb_coverage::type_id::create("cov", this);
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    agent.ap.connect(scb.imp);
    agent.ap.connect(cov.analysis_export);
  endfunction
endclass

// ──── Base Test ────
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
endclass

// ──── Write-Read Test ────
class apb_write_read_test extends apb_base_test;
  `uvm_component_utils(apb_write_read_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual task run_phase(uvm_phase phase);
    apb_write_read_seq seq = apb_write_read_seq::type_id::create("seq");
    phase.raise_objection(this);
    seq.start(env.agent.sqr);
    #200;
    phase.drop_objection(this);
  endtask
endclass
```

#### Top-Level Module

```systemverilog
module tb_top;
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  logic clk, rst_n;

  apb_if apb_vif(.clk(clk), .rst_n(rst_n));

  // DUT instantiation
  apb_slave dut (
    .clk    (clk),
    .rst_n  (rst_n),
    .psel   (apb_vif.psel),
    .penable(apb_vif.penable),
    .paddr  (apb_vif.paddr),
    .pwrite (apb_vif.pwrite),
    .pwdata (apb_vif.pwdata),
    .prdata (apb_vif.prdata),
    .pready (apb_vif.pready),
    .pslverr(apb_vif.pslverr)
  );

  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  initial begin
    rst_n = 0;
    #20;
    rst_n = 1;
  end

  initial begin
    uvm_config_db #(virtual apb_if)::set(null, "uvm_test_top.env.agent.*", "vif", apb_vif);
    run_test();   // Test name from +UVM_TESTNAME
  end
endmodule
```

---

## Appendix A — Quick Reference: UVM Class Method Cheat Sheet

### `uvm_object` Methods

| Method | Must Override? | Purpose |
|--------|:--------------:|---------|
| `new(name)` | Yes | Constructor |
| `do_copy(rhs)` | Recommended | Field-by-field copy |
| `do_compare(rhs, comparer)` | Recommended | Equality check |
| `convert2string()` | Recommended | Simple string format |
| `do_print(printer)` | Optional | Structured printing |
| `do_pack(packer)` | Optional | Serialize |
| `do_unpack(packer)` | Optional | Deserialize |
| `do_record(recorder)` | Optional | Waveform recording |

### `uvm_component` Phase Methods

| Phase | Type | Direction | Override? |
|-------|------|-----------|-----------|
| `build_phase` | function | Top-down | Almost always |
| `connect_phase` | function | Bottom-up | When connecting ports |
| `end_of_elaboration_phase` | function | Bottom-up | Rarely |
| `start_of_simulation_phase` | function | Bottom-up | Rarely |
| `run_phase` | task | Parallel | In drivers, monitors, tests |
| `extract_phase` | function | Bottom-up | In scoreboards |
| `check_phase` | function | Bottom-up | In scoreboards |
| `report_phase` | function | Bottom-up | In scoreboards, coverage |
| `final_phase` | function | Top-down | Rarely |

### Factory Macros

| Macro | Used In |
|-------|---------|
| `` `uvm_object_utils(T) `` | `uvm_object` subclasses |
| `` `uvm_object_utils_begin(T) / _end `` | With field automation |
| `` `uvm_component_utils(T) `` | `uvm_component` subclasses |
| `` `uvm_component_utils_begin(T) / _end `` | With field automation |
| `` `uvm_object_param_utils(T) `` | Parameterized objects |
| `` `uvm_component_param_utils(T) `` | Parameterized components |

---

## Appendix B — Common Patterns and Idioms

### Pattern 1: Configuration Object

```systemverilog
class apb_config extends uvm_object;
  `uvm_object_utils(apb_config)

  uvm_active_passive_enum is_active = UVM_ACTIVE;
  bit                     has_coverage = 1;
  int                     num_transactions = 100;
  bit [31:0]              base_addr = 32'h0000_0000;

  function new(string name = "apb_config");
    super.new(name);
  endfunction
endclass

// Set in test
class my_test extends uvm_test;
  virtual function void build_phase(uvm_phase phase);
    apb_config cfg = apb_config::type_id::create("cfg");
    cfg.num_transactions = 200;
    cfg.has_coverage     = 1;
    uvm_config_db #(apb_config)::set(this, "env.*", "cfg", cfg);
  endfunction
endclass

// Get in agent
class apb_agent extends uvm_agent;
  apb_config cfg;

  virtual function void build_phase(uvm_phase phase);
    if (!uvm_config_db #(apb_config)::get(this, "", "cfg", cfg))
      `uvm_fatal("CFG", "Config object not found")
  endfunction
endclass
```

### Pattern 2: Sequence Library

```systemverilog
class apb_seq_lib extends uvm_sequence_library #(apb_transaction);
  `uvm_object_utils(apb_seq_lib)
  `uvm_sequence_library_utils(apb_seq_lib)

  function new(string name = "apb_seq_lib");
    super.new(name);
    init_sequence_library();
  endfunction
endclass

// Register sequences with the library
class apb_random_seq extends apb_base_seq;
  `uvm_object_utils(apb_random_seq)
  `uvm_add_to_seq_lib(apb_random_seq, apb_seq_lib)

  virtual task body();
    repeat (10) begin
      `uvm_do(req)
    end
  endtask
endclass
```

### Pattern 3: Layered Sequences

```systemverilog
class protocol_layer_seq extends uvm_sequence #(byte_txn);
  `uvm_object_utils(protocol_layer_seq)

  uvm_sequencer #(packet_txn) upper_sqr;

  virtual task body();
    packet_txn pkt;
    forever begin
      upper_sqr.get_next_item(pkt);

      foreach (pkt.payload[i]) begin
        byte_txn b = byte_txn::type_id::create("b");
        start_item(b);
        b.data = pkt.payload[i];
        b.sof  = (i == 0);
        b.eof  = (i == pkt.payload.size() - 1);
        finish_item(b);
      end

      upper_sqr.item_done();
    end
  endtask
endclass
```

---

## Appendix C — Glossary

| Term | Definition |
|------|------------|
| **Handle** | A reference (pointer) to a class object |
| **Factory** | A design pattern that creates objects indirectly, allowing type substitution |
| **TLM** | Transaction Level Modeling — communication abstraction between components |
| **Analysis Port** | A publish-subscribe broadcast port (1-to-many) |
| **Sequencer** | Arbitrates between sequences and feeds transactions to a driver |
| **Phase** | A lifecycle stage (build, connect, run, etc.) |
| **Objection** | A mechanism to keep a phase alive until work is complete |
| **RAL** | Register Abstraction Layer — mirror of DUT registers in the testbench |
| **Config DB** | Hierarchical configuration database for passing settings |
| **Virtual Interface** | A handle to a `module`-level interface, passable through classes |
| **Covergroup** | SystemVerilog construct for functional coverage |
| **Constraint** | Declarative rule guiding random value generation |
| **`$cast`** | Runtime type-safe downcast operation |
| **Field Automation** | Macros that auto-generate `copy`, `compare`, `print`, etc. |
