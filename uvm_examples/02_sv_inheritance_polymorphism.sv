// =============================================================================
// Example 02: Inheritance, Polymorphism, and Abstract Classes
// Demonstrates: extends, super, virtual methods, dynamic casting ($cast),
//               abstract classes, pure virtual methods.
// =============================================================================

// --- Base class with virtual methods ---
class BusTransaction;
  rand bit [31:0] addr;
  rand bit [31:0] data;
       bit        status;
       int unsigned id;
  static int unsigned next_id = 0;

  function new(string name = "BusTransaction");
    next_id++;
    id = next_id;
  endfunction

  virtual function string get_type_name();
    return "BusTransaction";
  endfunction

  virtual function void display();
    $display("[%s #%0d] addr=0x%08h data=0x%08h status=%0b",
             get_type_name(), id, addr, data, status);
  endfunction

  virtual function bit compare(BusTransaction other);
    return (this.addr == other.addr) &&
           (this.data == other.data) &&
           (this.status == other.status);
  endfunction

  virtual function BusTransaction clone();
    BusTransaction c = new();
    c.addr   = this.addr;
    c.data   = this.data;
    c.status = this.status;
    return c;
  endfunction
endclass

// --- Write transaction (extends BusTransaction) ---
class WriteTransaction extends BusTransaction;
  rand bit [3:0] byte_enable;
  rand bit       posted;

  function new(string name = "WriteTransaction");
    super.new(name);
    byte_enable = 4'hF;
  endfunction

  virtual function string get_type_name();
    return "WriteTransaction";
  endfunction

  virtual function void display();
    super.display();
    $display("  byte_enable=0b%04b posted=%0b", byte_enable, posted);
  endfunction

  virtual function bit compare(BusTransaction other);
    WriteTransaction other_wr;
    if (!super.compare(other)) return 0;
    if (!$cast(other_wr, other)) return 0;
    return (this.byte_enable == other_wr.byte_enable) &&
           (this.posted == other_wr.posted);
  endfunction

  virtual function BusTransaction clone();
    WriteTransaction c = new();
    c.addr        = this.addr;
    c.data        = this.data;
    c.status      = this.status;
    c.byte_enable = this.byte_enable;
    c.posted      = this.posted;
    return c;
  endfunction
endclass

// --- Read transaction (extends BusTransaction) ---
class ReadTransaction extends BusTransaction;
  rand bit [7:0] burst_length;

  constraint c_burst {
    burst_length inside {1, 2, 4, 8, 16};
  }

  function new(string name = "ReadTransaction");
    super.new(name);
  endfunction

  virtual function string get_type_name();
    return "ReadTransaction";
  endfunction

  virtual function void display();
    super.display();
    $display("  burst_length=%0d", burst_length);
  endfunction

  virtual function BusTransaction clone();
    ReadTransaction c = new();
    c.addr         = this.addr;
    c.data         = this.data;
    c.status       = this.status;
    c.burst_length = this.burst_length;
    return c;
  endfunction
endclass

// --- Abstract class with pure virtual methods ---
virtual class ProtocolDriver;
  string name;

  function new(string name);
    this.name = name;
  endfunction

  pure virtual task reset();
  pure virtual task drive(BusTransaction txn);
  pure virtual task wait_for_idle();

  virtual function void report();
    $display("[%s] Protocol driver report — no data to report", name);
  endfunction
endclass

// --- Concrete implementation of abstract class ---
class AHB_Driver extends ProtocolDriver;
  int unsigned transactions_driven;

  function new(string name = "AHB_Driver");
    super.new(name);
    transactions_driven = 0;
  endfunction

  virtual task reset();
    $display("[%s] AHB reset asserted", name);
    #10;
    $display("[%s] AHB reset deasserted", name);
  endtask

  virtual task drive(BusTransaction txn);
    $display("[%s] Driving AHB transaction:", name);
    txn.display();
    #5;
    txn.status = 1;
    transactions_driven++;
  endtask

  virtual task wait_for_idle();
    $display("[%s] Waiting for AHB bus idle", name);
    #2;
  endtask

  virtual function void report();
    $display("[%s] AHB Driver — transactions driven: %0d",
             name, transactions_driven);
  endfunction
endclass

class APB_Driver extends ProtocolDriver;
  int unsigned transactions_driven;

  function new(string name = "APB_Driver");
    super.new(name);
    transactions_driven = 0;
  endfunction

  virtual task reset();
    $display("[%s] APB preset_n asserted", name);
    #5;
    $display("[%s] APB preset_n deasserted", name);
  endtask

  virtual task drive(BusTransaction txn);
    $display("[%s] Driving APB transaction (setup phase):", name);
    #2;
    $display("[%s] APB access phase:", name);
    txn.display();
    #3;
    txn.status = 1;
    transactions_driven++;
  endtask

  virtual task wait_for_idle();
    $display("[%s] APB bus idle", name);
    #1;
  endtask

  virtual function void report();
    $display("[%s] APB Driver — transactions driven: %0d",
             name, transactions_driven);
  endfunction
endclass

// --- Testbench ---
module tb_inheritance;
  initial begin
    // ---- Polymorphism with Virtual Methods ----
    $display("\n===== Polymorphism Demo =====");
    BusTransaction txn_array[4];

    txn_array[0] = new();
    txn_array[0].addr = 32'h0000_1000;
    txn_array[0].data = 32'hAAAA_AAAA;

    begin
      WriteTransaction wr = new();
      wr.addr = 32'h0000_2000;
      wr.data = 32'hBBBB_BBBB;
      wr.byte_enable = 4'hC;
      wr.posted = 1;
      txn_array[1] = wr;
    end

    begin
      ReadTransaction rd = new();
      rd.addr = 32'h0000_3000;
      rd.burst_length = 8;
      txn_array[2] = rd;
    end

    begin
      WriteTransaction wr2 = new();
      wr2.addr = 32'h0000_4000;
      wr2.data = 32'hDDDD_DDDD;
      wr2.byte_enable = 4'hF;
      txn_array[3] = wr2;
    end

    $display("\nIterating with base-class handles:");
    foreach (txn_array[i]) begin
      $display("--- Element %0d ---", i);
      txn_array[i].display();
    end

    // ---- Dynamic Casting ----
    $display("\n===== Dynamic Casting ($cast) =====");
    foreach (txn_array[i]) begin
      WriteTransaction wr_handle;
      ReadTransaction  rd_handle;

      if ($cast(wr_handle, txn_array[i]))
        $display("[%0d] is a WriteTransaction, byte_enable=0b%04b",
                 i, wr_handle.byte_enable);
      else if ($cast(rd_handle, txn_array[i]))
        $display("[%0d] is a ReadTransaction, burst_length=%0d",
                 i, rd_handle.burst_length);
      else
        $display("[%0d] is a base BusTransaction", i);
    end

    // ---- Cloning ----
    $display("\n===== Clone Demo =====");
    BusTransaction original = txn_array[1];
    BusTransaction cloned   = original.clone();

    $display("Original:");
    original.display();
    $display("Cloned:");
    cloned.display();

    cloned.data = 32'hFFFF_FFFF;
    $display("\nAfter modifying clone:");
    $display("Original data: 0x%08h", original.data);
    $display("Cloned data:   0x%08h", cloned.data);

    // ---- Compare ----
    $display("\n===== Compare Demo =====");
    BusTransaction a = txn_array[1].clone();
    BusTransaction b = txn_array[1].clone();
    $display("a == b? %0b", a.compare(b));

    b.data = 32'h1111_1111;
    $display("After modifying b: a == b? %0b", a.compare(b));

    // ---- Abstract Class / Protocol Drivers ----
    $display("\n===== Abstract Class Demo =====");
    ProtocolDriver drivers[2];
    drivers[0] = new AHB_Driver("ahb0");
    drivers[1] = new APB_Driver("apb0");

    WriteTransaction wr_txn = new();
    wr_txn.addr = 32'hCAFE_0000;
    wr_txn.data = 32'h1234_5678;

    foreach (drivers[i]) begin
      $display("\n--- Driver %0d ---", i);
      drivers[i].reset();
      drivers[i].drive(wr_txn);
      drivers[i].wait_for_idle();
      drivers[i].report();
    end

    $display("\n===== All tests passed =====");
  end
endmodule
