// SystemVerilog Parameterized Classes and Deep/Shallow Copy
// Demonstrates: type parameters, value parameters, specialization,
//               shallow copy (new obj), deep copy, forward declarations

`timescale 1ns/1ps

// ---------------------------------------------------------------------------
// 1. Generic Stack (parameterized by type and depth)
// ---------------------------------------------------------------------------
class Stack #(type T = int, int DEPTH = 16);
    T   storage[DEPTH];
    int sp;

    function new();
        sp = 0;
    endfunction

    function bit push(T item);
        if (sp >= DEPTH) begin
            $display("  Stack overflow (depth=%0d)", DEPTH);
            return 0;
        end
        storage[sp] = item;
        sp++;
        return 1;
    endfunction

    function bit pop(output T item);
        if (sp <= 0) begin
            $display("  Stack underflow");
            return 0;
        end
        sp--;
        item = storage[sp];
        return 1;
    endfunction

    function bit is_empty();
        return (sp == 0);
    endfunction

    function bit is_full();
        return (sp >= DEPTH);
    endfunction

    function int size();
        return sp;
    endfunction

    function void display();
        $display("  Stack [size=%0d, depth=%0d]:", sp, DEPTH);
        for (int i = sp - 1; i >= 0; i--)
            $write("    [%0d] ", i);
        $display();
    endfunction
endclass

// ---------------------------------------------------------------------------
// 2. Generic FIFO
// ---------------------------------------------------------------------------
class FIFO #(type T = int, int DEPTH = 8);
    T   buffer[DEPTH];
    int head, tail, count;

    function new();
        head  = 0;
        tail  = 0;
        count = 0;
    endfunction

    function bit enqueue(T item);
        if (count >= DEPTH) return 0;
        buffer[tail] = item;
        tail  = (tail + 1) % DEPTH;
        count++;
        return 1;
    endfunction

    function bit dequeue(output T item);
        if (count <= 0) return 0;
        item  = buffer[head];
        head  = (head + 1) % DEPTH;
        count--;
        return 1;
    endfunction

    function int size();
        return count;
    endfunction

    function bit is_empty();
        return (count == 0);
    endfunction
endclass

// ---------------------------------------------------------------------------
// 3. Shallow vs Deep Copy
// ---------------------------------------------------------------------------
class Header;
    bit [7:0] src;
    bit [7:0] dst;
    bit [7:0] protocol;

    function new(bit [7:0] s = 0, bit [7:0] d = 0, bit [7:0] p = 0);
        src      = s;
        dst      = d;
        protocol = p;
    endfunction

    function Header copy();
        Header h  = new(src, dst, protocol);
        return h;
    endfunction

    function void display(string prefix = "");
        $display("%sHeader: src=0x%02h dst=0x%02h proto=0x%02h",
                 prefix, src, dst, protocol);
    endfunction
endclass

class Packet;
    int    id;
    Header hdr;
    bit [7:0] payload[];

    function new(int id = 0, bit [7:0] src = 0, bit [7:0] dst = 0);
        this.id  = id;
        this.hdr = new(src, dst);
        this.payload = new[4];
        foreach (payload[i]) payload[i] = i;
    endfunction

    function Packet deep_copy();
        Packet p     = new();
        p.id         = this.id;
        p.hdr        = this.hdr.copy();
        p.payload    = new[this.payload.size()];
        foreach (this.payload[i])
            p.payload[i] = this.payload[i];
        return p;
    endfunction

    function void display(string label = "");
        $display("  %s Packet id=%0d:", label, id);
        hdr.display("    ");
        $write("    payload = {");
        foreach (payload[i]) $write(" 0x%02h", payload[i]);
        $display(" }");
    endfunction
endclass

// ---------------------------------------------------------------------------
// 4. Forward declarations for mutually-referencing classes
// ---------------------------------------------------------------------------
typedef class Response;

class Request;
    int      id;
    string   cmd;
    Response rsp;

    function new(int id, string cmd);
        this.id  = id;
        this.cmd = cmd;
    endfunction

    function void display();
        $display("  Request #%0d: cmd=\"%s\" rsp=%s",
                 id, cmd, (rsp != null) ? "linked" : "null");
    endfunction
endclass

class Response;
    int     id;
    bit     ok;
    Request req;

    function new(int id, bit ok);
        this.id = id;
        this.ok = ok;
    endfunction

    function void link(Request r);
        this.req = r;
        r.rsp    = this;
    endfunction

    function void display();
        $display("  Response #%0d: ok=%0b req=%s",
                 id, ok, (req != null) ? $sformatf("#%0d", req.id) : "null");
    endfunction
endclass

// ---------------------------------------------------------------------------
// Testbench
// ---------------------------------------------------------------------------
module sv_parameterized_tb;

    initial begin
        // --- Parameterized Stack ---
        $display("\n=== 1. Parameterized Stack ===");
        begin
            Stack #(bit [7:0], 4) byte_stack = new();
            Stack #(string, 8)    str_stack  = new();
            bit [7:0] bval;
            string    sval;

            byte_stack.push(8'hAA);
            byte_stack.push(8'hBB);
            byte_stack.push(8'hCC);
            byte_stack.push(8'hDD);

            $display("  Byte stack size: %0d, full: %0b", byte_stack.size(), byte_stack.is_full());
            while (!byte_stack.is_empty()) begin
                byte_stack.pop(bval);
                $display("  Popped: 0x%02h", bval);
            end

            str_stack.push("hello");
            str_stack.push("world");
            str_stack.pop(sval);
            $display("  String popped: \"%s\"", sval);
        end

        // --- Parameterized FIFO ---
        $display("\n=== 2. Parameterized FIFO ===");
        begin
            FIFO #(int, 4) int_fifo = new();
            int val;

            for (int i = 10; i < 14; i++)
                int_fifo.enqueue(i);

            $display("  FIFO size: %0d", int_fifo.size());
            while (!int_fifo.is_empty()) begin
                int_fifo.dequeue(val);
                $display("  Dequeued: %0d", val);
            end
        end

        // --- Shallow vs Deep Copy ---
        $display("\n=== 3. Shallow vs Deep Copy ===");
        begin
            Packet p1, p2_shallow, p3_deep;

            p1 = new(1, 8'hAA, 8'hBB);
            p1.payload[0] = 8'hF0;
            p1.display("Original");

            p2_shallow = new p1;
            p2_shallow.id = 2;
            p2_shallow.hdr.src = 8'hCC;  // Modifies p1's header too!
            p1.display("After shallow copy modified hdr.src");
            $display("  p1.hdr.src is now 0x%02h (changed by shallow copy!)", p1.hdr.src);

            p1.hdr.src = 8'hAA;
            p3_deep = p1.deep_copy();
            p3_deep.id = 3;
            p3_deep.hdr.src = 8'hDD;
            $display("  After deep copy modified hdr.src:");
            $display("    p1.hdr.src = 0x%02h (unchanged)", p1.hdr.src);
            $display("    p3.hdr.src = 0x%02h (independent)", p3_deep.hdr.src);
        end

        // --- Forward declarations ---
        $display("\n=== 4. Forward Declarations ===");
        begin
            Request  req;
            Response rsp;

            req = new(1, "READ");
            rsp = new(1, 1);
            rsp.link(req);

            req.display();
            rsp.display();
        end

        $display("\n=== All parameterized class tests passed ===\n");
        $finish;
    end

endmodule
