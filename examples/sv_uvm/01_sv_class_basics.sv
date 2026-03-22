// =============================================================================
// Example 01: SystemVerilog Class Basics
// Covers: class declaration, handles, constructors, properties, methods,
//         this keyword, and object lifetime
// =============================================================================

class Packet;
  bit [7:0]  src_addr;
  bit [7:0]  dst_addr;
  bit [31:0] payload;
  bit        valid;
  int        id;

  static int pkt_count = 0;

  function new(bit [7:0] src = 0, bit [7:0] dst = 0);
    this.src_addr = src;
    this.dst_addr = dst;
    this.valid    = 0;
    pkt_count++;
    this.id = pkt_count;
  endfunction

  function void set_payload(bit [31:0] data);
    this.payload = data;
    this.valid   = 1;
  endfunction

  function bit [31:0] get_payload();
    if (!valid)
      $warning("Packet %0d: reading invalid payload", id);
    return payload;
  endfunction

  function void display();
    $display("Packet #%0d: src=0x%02h dst=0x%02h payload=0x%08h valid=%0b",
             id, src_addr, dst_addr, payload, valid);
  endfunction

  static function int get_count();
    return pkt_count;
  endfunction
endclass


class Header;
  bit [7:0] version;
  bit [7:0] protocol;

  function new(bit [7:0] ver = 1, bit [7:0] proto = 0);
    version  = ver;
    protocol = proto;
  endfunction

  function void display();
    $display("  Header: version=%0d protocol=%0d", version, protocol);
  endfunction
endclass


class Frame;
  Header     hdr;
  Packet     pkt;
  bit [15:0] checksum;

  function new();
    hdr = new(2, 8'h11);
    pkt = new(8'hAA, 8'hBB);
  endfunction

  function void compute_checksum();
    checksum = pkt.src_addr ^ pkt.dst_addr ^ pkt.payload[15:0];
  endfunction

  function void display();
    $display("=== Frame ===");
    hdr.display();
    pkt.display();
    $display("  Checksum: 0x%04h", checksum);
  endfunction

  function Frame deep_copy();
    Frame f     = new();
    f.hdr       = new(this.hdr.version, this.hdr.protocol);
    f.pkt       = new(this.pkt.src_addr, this.pkt.dst_addr);
    f.pkt.set_payload(this.pkt.payload);
    f.checksum  = this.checksum;
    return f;
  endfunction
endclass


module tb_class_basics;
  initial begin
    Packet p1, p2, p3;

    $display("\n=== Part 1: Basic Class Usage ===");
    p1 = new(8'h10, 8'h20);
    p1.set_payload(32'hDEAD_BEEF);
    p1.display();

    p2 = new(.dst(8'hFF));
    p2.set_payload(32'hCAFE_BABE);
    p2.display();

    $display("Total packets created: %0d", Packet::get_count());

    $display("\n=== Part 2: Handle Assignment (Shared Reference) ===");
    p3 = p1;
    $display("p3.src_addr before change: 0x%02h", p3.src_addr);
    p3.src_addr = 8'hFF;
    $display("p1.src_addr after p3 change: 0x%02h (same object!)", p1.src_addr);

    $display("\n=== Part 3: Shallow Copy ===");
    p3 = new p2;
    p3.src_addr = 8'h99;
    $display("p2.src_addr: 0x%02h (unchanged)", p2.src_addr);
    $display("p3.src_addr: 0x%02h (independent copy)", p3.src_addr);

    $display("\n=== Part 4: Composition and Deep Copy ===");
    begin
      Frame f1 = new();
      Frame f2;
      f1.pkt.set_payload(32'h1234_5678);
      f1.compute_checksum();

      f2 = f1.deep_copy();
      f2.hdr.version = 3;
      f2.pkt.src_addr = 8'hCC;

      $display("Original:");
      f1.display();
      $display("Deep copy (modified):");
      f2.display();
    end

    $display("\n=== Part 5: Null Handle Check ===");
    begin
      Packet p_null;
      if (p_null == null)
        $display("Handle is null — must call new() before use");
      p_null = new();
      $display("Handle is now valid, id=%0d", p_null.id);
    end

    $display("\nTotal packets created overall: %0d", Packet::get_count());
  end
endmodule
