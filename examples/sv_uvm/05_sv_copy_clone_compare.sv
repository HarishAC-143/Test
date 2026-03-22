// =============================================================================
// SystemVerilog Shallow Copy, Deep Copy, and Object Comparison
// =============================================================================
//
// Demonstrates:
//   - Shallow copy pitfalls (shared nested objects)
//   - Manual deep copy implementation
//   - Object comparison methods
//   - The UVM do_copy / do_compare pattern (pure SV version)

class Coordinate;
    int x, y;

    function new(int x = 0, int y = 0);
        this.x = x;
        this.y = y;
    endfunction

    function Coordinate clone();
        Coordinate c = new(x, y);
        return c;
    endfunction

    function bit equals(Coordinate other);
        if (other == null) return 0;
        return (x == other.x && y == other.y);
    endfunction

    function string to_string();
        return $sformatf("(%0d, %0d)", x, y);
    endfunction
endclass

class Shape;
    string      name;
    Coordinate  position;    // nested object
    int         color;

    function new(string name, int x = 0, int y = 0, int color = 0);
        this.name     = name;
        this.position = new(x, y);
        this.color    = color;
    endfunction

    // Shallow copy — position handle is shared!
    function Shape shallow_copy();
        Shape s = new this;
        return s;
    endfunction

    // Deep copy — position is independently cloned
    function Shape deep_copy();
        Shape s = new(name, 0, 0, color);
        s.position = position.clone();
        return s;
    endfunction

    function bit equals(Shape other);
        if (other == null) return 0;
        return (name == other.name &&
                position.equals(other.position) &&
                color == other.color);
    endfunction

    function void display();
        $display("[Shape] name=%s pos=%s color=%0d",
                 name, position.to_string(), color);
    endfunction
endclass

// ---- Complex object with dynamic array (deeper nesting) ----
class DataPacket;
    int              id;
    bit [7:0]        data[];        // dynamic array
    Coordinate       waypoints[$];  // queue of objects

    function new(int id = 0);
        this.id = id;
    endfunction

    function void add_data(bit [7:0] bytes[]);
        data = new[bytes.size()](bytes);
    endfunction

    function void add_waypoint(int x, int y);
        Coordinate wp = new(x, y);
        waypoints.push_back(wp);
    endfunction

    function DataPacket deep_copy();
        DataPacket copy = new(id);
        copy.data = new[data.size()];
        foreach (data[i])
            copy.data[i] = data[i];
        foreach (waypoints[i])
            copy.waypoints.push_back(waypoints[i].clone());
        return copy;
    endfunction

    function bit equals(DataPacket other);
        if (other == null) return 0;
        if (id != other.id) return 0;
        if (data.size() != other.data.size()) return 0;
        foreach (data[i])
            if (data[i] != other.data[i]) return 0;
        if (waypoints.size() != other.waypoints.size()) return 0;
        foreach (waypoints[i])
            if (!waypoints[i].equals(other.waypoints[i])) return 0;
        return 1;
    endfunction

    function void display();
        $write("[DataPacket #%0d] data(%0d bytes)=[", id, data.size());
        foreach (data[i])
            $write("%s0x%02h", (i > 0) ? "," : "", data[i]);
        $write("]  waypoints=[");
        foreach (waypoints[i])
            $write("%s%s", (i > 0) ? "," : "", waypoints[i].to_string());
        $display("]");
    endfunction
endclass

module tb_copy_compare;
    initial begin
        // --- Shallow vs Deep Copy ---
        $display("=== Shallow vs Deep Copy ===\n");
        begin
            Shape original, shallow, deep;

            original = new("circle", 10, 20, 255);
            original.display();

            shallow = original.shallow_copy();
            deep    = original.deep_copy();

            $display("\nAfter copying:");
            $display("Original:"); original.display();
            $display("Shallow:");  shallow.display();
            $display("Deep:");     deep.display();

            // Modify the original's position
            original.position.x = 99;
            original.position.y = 88;

            $display("\nAfter modifying original position to (99,88):");
            $display("Original:"); original.display();
            $display("Shallow:");  shallow.display();  // CHANGED — shares position!
            $display("Deep:");     deep.display();     // UNCHANGED — independent
        end

        // --- Complex Deep Copy ---
        $display("\n=== Complex Deep Copy ===\n");
        begin
            DataPacket orig, copy;
            bit [7:0] bytes[] = '{8'hAA, 8'hBB, 8'hCC, 8'hDD};

            orig = new(42);
            orig.add_data(bytes);
            orig.add_waypoint(0, 0);
            orig.add_waypoint(10, 5);
            orig.add_waypoint(20, 15);

            $display("Original:"); orig.display();

            copy = orig.deep_copy();
            $display("Deep copy:"); copy.display();

            // Modify original
            orig.data[0] = 8'hFF;
            orig.waypoints[1].x = 999;

            $display("\nAfter modifying original:");
            $display("Original:"); orig.display();
            $display("Deep copy:"); copy.display();  // unchanged
        end

        // --- Object Comparison ---
        $display("\n=== Object Comparison ===\n");
        begin
            Shape a, b, c;
            a = new("square", 5, 5, 100);
            b = new("square", 5, 5, 100);
            c = new("square", 5, 5, 200);

            $display("a == b (same values)?  %s", a.equals(b) ? "YES" : "NO");
            $display("a == c (diff color)?   %s", a.equals(c) ? "YES" : "NO");

            // Handle comparison (reference identity)
            $display("a === a (same handle)? %s", (a === a) ? "YES" : "NO");
            $display("a === b (diff handle)? %s", (a === b) ? "YES" : "NO");
        end

        // --- DataPacket comparison ---
        $display("\n--- DataPacket Comparison ---");
        begin
            DataPacket p1, p2, p3;
            bit [7:0] d1[] = '{8'h01, 8'h02};
            bit [7:0] d2[] = '{8'h01, 8'h03};

            p1 = new(1);
            p1.add_data(d1);
            p1.add_waypoint(1, 1);

            p2 = p1.deep_copy();
            p3 = new(1);
            p3.add_data(d2);
            p3.add_waypoint(1, 1);

            $display("p1 == p2 (deep copy)?   %s", p1.equals(p2) ? "YES" : "NO");
            $display("p1 == p3 (diff data)?   %s", p1.equals(p3) ? "YES" : "NO");
        end

        $finish;
    end
endmodule
