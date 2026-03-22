// =============================================================================
// Example 01: SystemVerilog Class Basics
// Demonstrates: class declaration, properties, methods, constructors,
//               handles, object lifetime, and the `this` keyword.
// =============================================================================

// --- Basic class declaration ---
class Packet;
  // Properties
  bit [7:0]  addr;
  bit [31:0] data;
  bit        write;
  string     tag;

  // Constructor
  function new(bit [7:0] addr = 0, bit [31:0] data = 0, bit write = 0);
    this.addr  = addr;
    this.data  = data;
    this.write = write;
    this.tag   = "default";
  endfunction

  // Display method
  function void display(string prefix = "");
    $display("%sPacket: addr=0x%02h data=0x%08h write=%0b tag=%s",
             prefix, addr, data, write, tag);
  endfunction

  // Compute a simple checksum
  function bit [7:0] checksum();
    return addr ^ data[7:0] ^ data[15:8] ^ data[23:16] ^ data[31:24] ^ {7'b0, write};
  endfunction
endclass

// --- Class with extern methods (out-of-body) ---
class Register;
  bit [31:0] value;
  string     name;
  bit        read_only;

  function new(string name, bit [31:0] reset_val = 0, bit read_only = 0);
    this.name      = name;
    this.value     = reset_val;
    this.read_only = read_only;
  endfunction

  extern function bit write(bit [31:0] data);
  extern function bit [31:0] read();
  extern function void display();
endclass

function bit Register::write(bit [31:0] data);
  if (read_only) begin
    $display("ERROR: Attempt to write read-only register '%s'", name);
    return 0;
  end
  value = data;
  return 1;
endfunction

function bit [31:0] Register::read();
  return value;
endfunction

function void Register::display();
  $display("Register '%s': value=0x%08h %s",
           name, value, read_only ? "(RO)" : "(RW)");
endfunction

// --- Static members ---
class Transaction;
  static int unsigned count = 0;
  int unsigned id;
  bit [31:0]  addr;
  bit [31:0]  data;

  function new();
    count++;
    id = count;
  endfunction

  static function int unsigned get_count();
    return count;
  endfunction

  function void display();
    $display("Transaction #%0d: addr=0x%08h data=0x%08h", id, addr, data);
  endfunction
endclass

// --- Testbench ---
module tb_class_basics;
  initial begin
    // ---- Basic Object Creation ----
    $display("\n===== Basic Object Creation =====");
    Packet pkt1;

    $display("pkt1 is null: %0b", (pkt1 == null));
    pkt1 = new(8'hA0, 32'hDEAD_BEEF, 1);
    $display("pkt1 is null: %0b", (pkt1 == null));
    pkt1.display("  ");
    $display("Checksum: 0x%02h", pkt1.checksum());

    // ---- Handle Assignment (Aliasing) ----
    $display("\n===== Handle Aliasing =====");
    Packet pkt2 = pkt1;
    pkt2.tag = "aliased";
    pkt1.display("pkt1: ");
    pkt2.display("pkt2: ");
    $display("Same object? %0b", (pkt1 == pkt2));

    // ---- Independent Copy via new ----
    $display("\n===== Shallow Copy =====");
    Packet pkt3 = new pkt1;
    pkt3.tag  = "copied";
    pkt3.addr = 8'hFF;
    pkt1.display("pkt1: ");
    pkt3.display("pkt3: ");
    $display("Same object? %0b", (pkt1 == pkt3));

    // ---- Constructor Arguments ----
    $display("\n===== Named Constructor Arguments =====");
    Packet pkt4 = new(.addr(8'h55), .write(1));
    pkt4.display("pkt4: ");

    // ---- Register Class ----
    $display("\n===== Register Class =====");
    Register ctrl  = new("CTRL",   32'h0000_0001);
    Register status = new("STATUS", 32'h0000_0000, 1);

    ctrl.display();
    status.display();

    void'(ctrl.write(32'hABCD_1234));
    ctrl.display();

    void'(status.write(32'h1111_2222));
    status.display();

    // ---- Static Members ----
    $display("\n===== Static Members =====");
    Transaction t1 = new();
    t1.addr = 32'h1000;
    t1.data = 32'hAAAA;

    Transaction t2 = new();
    t2.addr = 32'h2000;
    t2.data = 32'hBBBB;

    Transaction t3 = new();
    t3.addr = 32'h3000;
    t3.data = 32'hCCCC;

    t1.display();
    t2.display();
    t3.display();
    $display("Total transactions created: %0d", Transaction::get_count());

    // ---- Null and Garbage Collection ----
    $display("\n===== Null Assignment =====");
    Packet temp = new(8'h01, 32'h1234_5678);
    temp.display("before null: ");
    temp = null;
    $display("temp is null: %0b", (temp == null));

    $display("\n===== All tests passed =====");
  end
endmodule
