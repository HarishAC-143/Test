# Chapter 4: Transactions & Sequence Items

## What Is a Transaction?

A **transaction** is an abstract representation of a single interaction with the DUT. Instead of thinking in terms of individual signal toggles, UVM models stimulus and responses as high-level objects.

| Signal-Level Thinking | Transaction-Level Thinking |
|----------------------|---------------------------|
| Set `addr` to `0x1000`, assert `wr_en`, put `0xDEAD` on `data_in`, wait one clock, deassert `wr_en` | "Write `0xDEAD` to address `0x1000`" |
| Assert `rd_en`, set `addr` to `0x2000`, wait for `data_valid`, capture `data_out` | "Read from address `0x2000`" |

This abstraction is fundamental to UVM's power — it separates **what** you want to do from **how** it gets done at the pin level.

## `uvm_sequence_item`

All transactions should extend `uvm_sequence_item`. This provides:

- Factory registration
- Built-in `copy()`, `compare()`, `print()`, `pack()` methods
- Integration with the sequencer-driver handshake
- Transaction recording support

### Basic Transaction Example

```systemverilog
typedef enum bit [2:0] {
  ADD  = 3'b000,
  SUB  = 3'b001,
  AND  = 3'b010,
  OR   = 3'b011,
  XOR  = 3'b100
} alu_op_t;

class alu_transaction extends uvm_sequence_item;
  `uvm_object_utils(alu_transaction)
  
  // Stimulus fields (randomized)
  rand bit [7:0]  operand_a;
  rand bit [7:0]  operand_b;
  rand alu_op_t   operation;
  
  // Response fields (not randomized — filled by driver/monitor)
  bit [7:0]  result;
  bit        carry_out;
  
  function new(string name = "alu_transaction");
    super.new(name);
  endfunction
  
  function string convert2string();
    return $sformatf("a=0x%02h b=0x%02h op=%s result=0x%02h carry=%0b",
                     operand_a, operand_b, operation.name(), result, carry_out);
  endfunction
endclass
```

## Constraints

Constraints are one of UVM's most powerful features. They let you define **rules** that the simulator's constraint solver must satisfy when randomizing a transaction.

### Basic Constraints

```systemverilog
class alu_transaction extends uvm_sequence_item;
  `uvm_object_utils(alu_transaction)
  
  rand bit [7:0]  operand_a;
  rand bit [7:0]  operand_b;
  rand alu_op_t   operation;
  bit [7:0]       result;
  
  // Only use valid operations
  constraint valid_ops_c {
    operation inside {ADD, SUB, AND, OR, XOR};
  }
  
  // Bias towards corner-case values
  constraint corner_cases_c {
    operand_a dist {
      0       := 10,   // 10% chance of zero
      8'hFF   := 10,   // 10% chance of max
      [1:8'hFE] := 80  // 80% chance of middle values
    };
  }
  
  // Conditional constraint
  constraint sub_no_underflow_c {
    (operation == SUB) -> (operand_a >= operand_b);
  }
  
  function new(string name = "alu_transaction");
    super.new(name);
  endfunction
endclass
```

### Constraint Layering

One of UVM's strengths is the ability to **add constraints in derived classes** without modifying the base transaction:

```systemverilog
// Base transaction — general purpose
class bus_transaction extends uvm_sequence_item;
  `uvm_object_utils(bus_transaction)
  
  rand bit [15:0] addr;
  rand bit [31:0] data;
  rand bit        write;
  
  constraint addr_align_c {
    addr[1:0] == 2'b00;  // Word-aligned addresses
  }
  
  function new(string name = "bus_transaction");
    super.new(name);
  endfunction
endclass

// Derived transaction — only writes to low memory
class low_memory_write_txn extends bus_transaction;
  `uvm_object_utils(low_memory_write_txn)
  
  constraint low_addr_c {
    addr < 16'h1000;
  }
  
  constraint write_only_c {
    write == 1;
  }
  
  function new(string name = "low_memory_write_txn");
    super.new(name);
  endfunction
endclass
```

Using factory overrides, you can swap `bus_transaction` with `low_memory_write_txn` in a test to focus stimulus on a specific region.

## Implementing `do_copy()`, `do_compare()`, and `convert2string()`

For production testbenches, implement these methods manually for best performance:

```systemverilog
class mem_transaction extends uvm_sequence_item;
  `uvm_object_utils(mem_transaction)
  
  rand bit [15:0] addr;
  rand bit [31:0] data;
  rand bit        write;
  bit [31:0]      read_data;
  
  function new(string name = "mem_transaction");
    super.new(name);
  endfunction
  
  // Deep copy
  function void do_copy(uvm_object rhs);
    mem_transaction rhs_;
    super.do_copy(rhs);
    $cast(rhs_, rhs);
    this.addr      = rhs_.addr;
    this.data      = rhs_.data;
    this.write     = rhs_.write;
    this.read_data = rhs_.read_data;
  endfunction
  
  // Field-by-field comparison
  function bit do_compare(uvm_object rhs, uvm_comparer comparer);
    mem_transaction rhs_;
    bit result = super.do_compare(rhs, comparer);
    $cast(rhs_, rhs);
    result &= (this.addr      == rhs_.addr);
    result &= (this.data      == rhs_.data);
    result &= (this.write     == rhs_.write);
    result &= (this.read_data == rhs_.read_data);
    return result;
  endfunction
  
  // Human-readable string representation
  function string convert2string();
    return $sformatf("%s addr=0x%04h data=0x%08h read_data=0x%08h",
                     write ? "WR" : "RD", addr, data, read_data);
  endfunction
endclass
```

## Stimulus vs. Response Fields

A clean convention is to separate stimulus fields (randomized inputs to the DUT) from response fields (outputs captured from the DUT):

```systemverilog
class spi_transaction extends uvm_sequence_item;
  `uvm_object_utils(spi_transaction)
  
  //--- Stimulus fields (set by sequence, driven by driver) ---
  rand bit [7:0]  tx_data;
  rand bit        cpol;
  rand bit        cpha;
  
  //--- Response fields (captured by driver or monitor) ---
  bit [7:0]  rx_data;
  bit        transfer_complete;
  
  function new(string name = "spi_transaction");
    super.new(name);
  endfunction
endclass
```

The driver sends `tx_data`, `cpol`, and `cpha` to the DUT, then fills in `rx_data` and `transfer_complete` from the DUT's response. This same transaction object flows through the entire testbench.

## Using `rand_mode()` and `constraint_mode()`

You can selectively enable or disable randomization and constraints at runtime:

```systemverilog
task body();
  mem_transaction txn = mem_transaction::type_id::create("txn");
  
  // Disable randomization of addr — set it manually
  txn.addr.rand_mode(0);
  txn.addr = 16'h0000;
  
  // Disable a specific constraint
  txn.addr_align_c.constraint_mode(0);
  
  start_item(txn);
  assert(txn.randomize());  // Only randomizes data and write
  finish_item(txn);
endtask
```

## Summary

| Concept | Description |
|---------|-------------|
| Transaction | Abstract representation of a DUT interaction |
| `uvm_sequence_item` | Base class for all transactions |
| Constraints | Rules the randomization solver must satisfy |
| `do_copy()` | Deep copy one transaction into another |
| `do_compare()` | Field-by-field equality check |
| `convert2string()` | Human-readable representation for debug |
| Stimulus fields | `rand` fields driven into the DUT |
| Response fields | Non-random fields captured from the DUT |
| Constraint layering | Add constraints in derived classes for targeted stimulus |

---

[← Previous: Chapter 3 — Components](03_components.md) | [Next: Chapter 5 — UVM Sequences →](05_sequences.md)
