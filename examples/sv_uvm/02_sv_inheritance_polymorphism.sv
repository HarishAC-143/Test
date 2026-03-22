// =============================================================================
// Example 02: Inheritance, Polymorphism, and Abstract Classes
// Covers: extends, super, virtual methods, pure virtual, $cast,
//         dynamic dispatch, and abstract class patterns
// =============================================================================

// --- Abstract base: pure virtual forces subclasses to implement ---
virtual class Transaction;
  static int txn_counter = 0;
  int        txn_id;

  function new();
    txn_counter++;
    txn_id = txn_counter;
  endfunction

  pure virtual function string convert2string();
  pure virtual function bit    is_valid();
  pure virtual function Transaction copy();

  function void display();
    $display("[TXN #%0d] %s %s",
             txn_id, convert2string(), is_valid() ? "(valid)" : "(INVALID)");
  endfunction
endclass


class ReadTransaction extends Transaction;
  bit [31:0] addr;
  bit [31:0] data;
  bit [3:0]  resp;

  function new(bit [31:0] addr = 0);
    super.new();
    this.addr = addr;
  endfunction

  virtual function string convert2string();
    return $sformatf("READ  addr=0x%08h data=0x%08h resp=%0d", addr, data, resp);
  endfunction

  virtual function bit is_valid();
    return (addr[1:0] == 2'b00);
  endfunction

  virtual function Transaction copy();
    ReadTransaction t = new(this.addr);
    t.data = this.data;
    t.resp = this.resp;
    return t;
  endfunction
endclass


class WriteTransaction extends Transaction;
  bit [31:0] addr;
  bit [31:0] data;
  bit [3:0]  strobe;
  bit [3:0]  resp;

  function new(bit [31:0] addr = 0, bit [31:0] data = 0, bit [3:0] strobe = 4'hF);
    super.new();
    this.addr   = addr;
    this.data   = data;
    this.strobe = strobe;
  endfunction

  virtual function string convert2string();
    return $sformatf("WRITE addr=0x%08h data=0x%08h strobe=0x%01h resp=%0d",
                     addr, data, strobe, resp);
  endfunction

  virtual function bit is_valid();
    return (addr[1:0] == 2'b00) && (strobe != 0);
  endfunction

  virtual function Transaction copy();
    WriteTransaction t = new(this.addr, this.data, this.strobe);
    t.resp = this.resp;
    return t;
  endfunction
endclass


class BurstWriteTransaction extends WriteTransaction;
  int        burst_len;
  bit [31:0] burst_data[];

  function new(bit [31:0] addr = 0, int burst_len = 4);
    super.new(addr);
    this.burst_len = burst_len;
    burst_data = new[burst_len];
  endfunction

  virtual function string convert2string();
    string s = $sformatf("BURST_WRITE addr=0x%08h len=%0d strobe=0x%01h",
                         addr, burst_len, strobe);
    foreach (burst_data[i])
      s = {s, $sformatf("\n    [%0d] 0x%08h", i, burst_data[i])};
    return s;
  endfunction

  virtual function bit is_valid();
    return super.is_valid() && (burst_len > 0) && (burst_len <= 256);
  endfunction

  virtual function Transaction copy();
    BurstWriteTransaction t = new(this.addr, this.burst_len);
    t.data       = this.data;
    t.strobe     = this.strobe;
    t.resp       = this.resp;
    t.burst_data = this.burst_data;
    return t;
  endfunction
endclass


// --- Interface classes (contracts) ---
interface class Scorable;
  pure virtual function bit [31:0] get_signature();
endclass

interface class Printable;
  pure virtual function void pretty_print();
endclass

class ScoredTransaction extends WriteTransaction implements Scorable, Printable;
  function new(bit [31:0] addr = 0, bit [31:0] data = 0);
    super.new(addr, data);
  endfunction

  virtual function bit [31:0] get_signature();
    return addr ^ data ^ {28'h0, strobe};
  endfunction

  virtual function void pretty_print();
    $display("┌────────────────────────────────┐");
    $display("│ Scored Transaction #%0d", txn_id);
    $display("│ Addr:   0x%08h", addr);
    $display("│ Data:   0x%08h", data);
    $display("│ Strobe: 0x%01h", strobe);
    $display("│ Sig:    0x%08h", get_signature());
    $display("└────────────────────────────────┘");
  endfunction
endclass


module tb_inheritance;
  initial begin
    Transaction txn_q[$];

    $display("\n=== Part 1: Polymorphism with Virtual Methods ===");
    begin
      ReadTransaction  rd = new(32'h0000_1000);
      WriteTransaction wr = new(32'h0000_2000, 32'hAAAA_BBBB);
      BurstWriteTransaction bwr = new(32'h0000_3000, 4);

      rd.data = 32'hDEAD_BEEF;
      foreach (bwr.burst_data[i])
        bwr.burst_data[i] = 32'h1000_0000 + i;

      txn_q.push_back(rd);
      txn_q.push_back(wr);
      txn_q.push_back(bwr);
    end

    $display("Iterating via base-class handle (polymorphic dispatch):");
    foreach (txn_q[i])
      txn_q[i].display();

    $display("\n=== Part 2: $cast (Downcasting) ===");
    foreach (txn_q[i]) begin
      WriteTransaction wr_handle;
      BurstWriteTransaction bwr_handle;

      if ($cast(bwr_handle, txn_q[i]))
        $display("  txn_q[%0d] is a BurstWriteTransaction, burst_len=%0d", i, bwr_handle.burst_len);
      else if ($cast(wr_handle, txn_q[i]))
        $display("  txn_q[%0d] is a WriteTransaction, strobe=0x%01h", i, wr_handle.strobe);
      else
        $display("  txn_q[%0d] is a ReadTransaction (or other)", i);
    end

    $display("\n=== Part 3: Virtual Copy Pattern ===");
    begin
      Transaction original = txn_q[2];
      Transaction cloned   = original.copy();
      BurstWriteTransaction bwr_cloned;
      $cast(bwr_cloned, cloned);
      bwr_cloned.burst_data[0] = 32'hFFFF_FFFF;
      $display("Original:");
      original.display();
      $display("Cloned (modified):");
      cloned.display();
    end

    $display("\n=== Part 4: Interface Classes ===");
    begin
      ScoredTransaction st = new(32'h4000, 32'hABCD_1234);
      st.pretty_print();
      $display("Signature: 0x%08h", st.get_signature());

      Scorable s_handle = st;
      $display("Via Scorable interface — signature: 0x%08h", s_handle.get_signature());
    end

    $display("\n=== Part 5: Validity Checks ===");
    begin
      ReadTransaction  rd_ok  = new(32'h100);
      ReadTransaction  rd_bad = new(32'h101);
      WriteTransaction wr_bad = new(32'h200, 32'hFF, 4'h0);

      $display("rd_ok valid:  %0b (aligned)", rd_ok.is_valid());
      $display("rd_bad valid: %0b (unaligned)", rd_bad.is_valid());
      $display("wr_bad valid: %0b (zero strobe)", wr_bad.is_valid());
    end

    $display("\nTotal transactions created: %0d", Transaction::txn_counter);
  end
endmodule
