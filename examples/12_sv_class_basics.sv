// SystemVerilog Class Basics — Properties, Methods, Constructors, Handles
// Demonstrates: class definition, new(), handle semantics, this keyword,
//               encapsulation (local/protected), static members

`timescale 1ns/1ps

// ---------------------------------------------------------------------------
// 1. Basic class with properties and methods
// ---------------------------------------------------------------------------
class Packet;
    bit [7:0]  src_addr;
    bit [7:0]  dst_addr;
    bit [31:0] payload;
    bit [15:0] crc;

    function new(bit [7:0] src = 0, bit [7:0] dst = 0, bit [31:0] data = 0);
        this.src_addr = src;
        this.dst_addr = dst;
        this.payload  = data;
        this.crc      = compute_crc();
    endfunction

    function bit [15:0] compute_crc();
        return src_addr ^ dst_addr ^ payload[15:0] ^ payload[31:16];
    endfunction

    function void display(string prefix = "");
        $display("%sPacket: src=0x%02h dst=0x%02h payload=0x%08h crc=0x%04h",
                 prefix, src_addr, dst_addr, payload, crc);
    endfunction
endclass

// ---------------------------------------------------------------------------
// 2. Encapsulation with local and protected
// ---------------------------------------------------------------------------
class SecurePacket;
    local    bit [7:0] encryption_key;
    protected bit [7:0] internal_id;
    bit [7:0] payload;

    function new(bit [7:0] key, bit [7:0] id, bit [7:0] data);
        encryption_key = key;
        internal_id    = id;
        payload        = data;
    endfunction

    function bit [7:0] get_encrypted();
        return payload ^ encryption_key;
    endfunction

    function bit [7:0] get_id();
        return internal_id;
    endfunction
endclass

class ExtendedSecurePacket extends SecurePacket;
    function new(bit [7:0] key, bit [7:0] id, bit [7:0] data);
        super.new(key, id, data);
    endfunction

    function void show_id();
        $display("  internal_id = 0x%02h (accessed via protected)", internal_id);
    endfunction

    // Cannot access encryption_key here — it is local to SecurePacket
endclass

// ---------------------------------------------------------------------------
// 3. Static members
// ---------------------------------------------------------------------------
class TrackedObject;
    static int total_count = 0;
    int id;
    string label;

    function new(string label);
        total_count++;
        this.id    = total_count;
        this.label = label;
    endfunction

    static function int get_total();
        return total_count;
    endfunction

    static function void reset_count();
        total_count = 0;
    endfunction

    function void display();
        $display("  TrackedObject #%0d: \"%s\"", id, label);
    endfunction
endclass

// ---------------------------------------------------------------------------
// 4. Handle semantics — assignment, null, comparison
// ---------------------------------------------------------------------------
class SimpleData;
    int value;

    function new(int v);
        value = v;
    endfunction
endclass

// ---------------------------------------------------------------------------
// Testbench
// ---------------------------------------------------------------------------
module sv_class_basics_tb;

    initial begin
        // --- Basic class usage ---
        $display("\n=== 1. Basic Class ===");
        begin
            Packet p1, p2;

            p1 = new(8'hAA, 8'hBB, 32'hDEAD_BEEF);
            p1.display("  ");

            p2 = new();
            p2.src_addr = 8'h11;
            p2.dst_addr = 8'h22;
            p2.payload  = 32'hCAFE_BABE;
            p2.crc      = p2.compute_crc();
            p2.display("  ");
        end

        // --- Encapsulation ---
        $display("\n=== 2. Encapsulation ===");
        begin
            ExtendedSecurePacket esp;
            esp = new(8'hFF, 8'h42, 8'hAB);
            $display("  encrypted payload = 0x%02h", esp.get_encrypted());
            esp.show_id();
        end

        // --- Static members ---
        $display("\n=== 3. Static Members ===");
        begin
            TrackedObject a, b, c;
            TrackedObject::reset_count();

            a = new("alpha");
            b = new("beta");
            c = new("gamma");

            a.display();
            b.display();
            c.display();
            $display("  Total objects created: %0d", TrackedObject::get_total());
        end

        // --- Handle semantics ---
        $display("\n=== 4. Handle Semantics ===");
        begin
            SimpleData d1, d2, d3;

            d1 = new(100);
            d2 = d1;           // Both point to the same object
            d3 = new(200);

            $display("  d1.value=%0d, d2.value=%0d (same object)", d1.value, d2.value);

            d2.value = 999;
            $display("  After d2.value=999: d1.value=%0d (confirms sharing)", d1.value);

            $display("  d1 == d2? %0b (same object)", d1 == d2);
            $display("  d1 == d3? %0b (different objects)", d1 == d3);

            d3 = null;
            $display("  d3 == null? %0b", d3 == null);
        end

        $display("\n=== All class basics tests passed ===\n");
        $finish;
    end

endmodule
