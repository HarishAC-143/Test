// =============================================================================
// SystemVerilog Parameterized Classes, Static Members, and Extern Methods
// =============================================================================
//
// Demonstrates:
//   - Parameterized (generic) classes with type and value parameters
//   - Static properties and methods
//   - Singleton pattern
//   - Extern method declarations
//   - Typedef for parameterized types

// ---- Parameterized Stack ----
class Stack #(type T = int, int MAX_DEPTH = 16);
    local T items[$];

    function void push(T item);
        if (items.size() >= MAX_DEPTH) begin
            $error("Stack overflow at depth %0d", MAX_DEPTH);
            return;
        end
        items.push_back(item);
    endfunction

    function T pop();
        if (items.size() == 0) begin
            $error("Stack underflow");
            return T'(0);
        end
        return items.pop_back();
    endfunction

    function T peek();
        if (items.size() == 0) begin
            $error("Stack empty — cannot peek");
            return T'(0);
        end
        return items[items.size() - 1];
    endfunction

    function int size();
        return items.size();
    endfunction

    function bit is_empty();
        return (items.size() == 0);
    endfunction

    function bit is_full();
        return (items.size() >= MAX_DEPTH);
    endfunction

    function void display();
        $display("Stack<%0d> [size=%0d/%0d]:", $bits(T), items.size(), MAX_DEPTH);
        foreach (items[i])
            $display("  [%0d]: %p", i, items[i]);
    endfunction
endclass

// ---- Parameterized FIFO ----
class FIFO #(type T = int, int DEPTH = 8);
    local T buffer[$];

    function bit enqueue(T item);
        if (buffer.size() >= DEPTH) return 0;
        buffer.push_back(item);
        return 1;
    endfunction

    function bit dequeue(output T item);
        if (buffer.size() == 0) return 0;
        item = buffer.pop_front();
        return 1;
    endfunction

    function int occupancy();
        return buffer.size();
    endfunction

    function bit is_full();
        return (buffer.size() >= DEPTH);
    endfunction
endclass

// ---- Static members: Transaction counter ----
class NumberedItem;
    static int  total_count = 0;
    static int  active_count = 0;
    int         id;
    string      label;

    function new(string label = "item");
        total_count++;
        active_count++;
        this.id    = total_count;
        this.label = label;
    endfunction

    static function int get_total();
        return total_count;
    endfunction

    static function int get_active();
        return active_count;
    endfunction

    static function void reset_counters();
        total_count  = 0;
        active_count = 0;
    endfunction

    function void destroy();
        active_count--;
        $display("Destroyed %s #%0d (active: %0d)", label, id, active_count);
    endfunction

    function void display();
        $display("[%s #%0d] (total=%0d active=%0d)",
                 label, id, total_count, active_count);
    endfunction
endclass

// ---- Singleton pattern ----
class ConfigManager;
    static local ConfigManager inst;

    int    timeout_ns;
    string dut_name;
    int    max_errors;

    local function new();
        timeout_ns = 1000;
        dut_name   = "default_dut";
        max_errors = 10;
    endfunction

    static function ConfigManager get_inst();
        if (inst == null)
            inst = new();
        return inst;
    endfunction

    function void display();
        $display("[Config] DUT=%s timeout=%0dns max_errors=%0d",
                 dut_name, timeout_ns, max_errors);
    endfunction
endclass

// ---- Extern methods ----
class Calculator;
    extern function int factorial(int n);
    extern function int fibonacci(int n);
    extern function real power(real base, int exp);
endclass

function int Calculator::factorial(int n);
    if (n <= 1) return 1;
    return n * factorial(n - 1);
endfunction

function int Calculator::fibonacci(int n);
    if (n <= 0) return 0;
    if (n == 1) return 1;
    return fibonacci(n - 1) + fibonacci(n - 2);
endfunction

function real Calculator::power(real base, int exp);
    real result = 1.0;
    for (int i = 0; i < exp; i++)
        result *= base;
    return result;
endfunction

// ---- Typedef for parameterized types ----
typedef Stack #(bit [31:0], 32) AddrStack;
typedef Stack #(string, 64)     NameStack;
typedef FIFO  #(bit [7:0], 256) ByteFIFO;

// ---- Testbench ----
module tb_parameterized;
    initial begin
        // --- Parameterized Stack ---
        $display("=== Parameterized Stack ===\n");
        begin
            AddrStack  addr_stk = new();
            NameStack  name_stk = new();

            for (int i = 0; i < 5; i++)
                addr_stk.push(32'h1000 + i * 4);

            addr_stk.display();

            $display("Pop: 0x%08h", addr_stk.pop());
            $display("Pop: 0x%08h", addr_stk.pop());
            $display("Peek: 0x%08h", addr_stk.peek());
            $display("Size: %0d", addr_stk.size());

            name_stk.push("alpha");
            name_stk.push("beta");
            name_stk.push("gamma");
            $display("\nName stack peek: %s", name_stk.pop());
        end

        // --- Parameterized FIFO ---
        $display("\n=== Parameterized FIFO ===\n");
        begin
            ByteFIFO fifo = new();
            bit [7:0] val;

            for (int i = 0; i < 5; i++)
                void'(fifo.enqueue(8'hA0 + i));

            $display("FIFO occupancy: %0d", fifo.occupancy());
            while (fifo.occupancy() > 0) begin
                void'(fifo.dequeue(val));
                $display("  Dequeued: 0x%02h", val);
            end
        end

        // --- Static members ---
        $display("\n=== Static Members ===\n");
        begin
            NumberedItem a, b, c;
            a = new("sensor");
            b = new("actuator");
            c = new("controller");
            a.display();
            b.display();
            c.display();

            b.destroy();
            $display("After destroying b — Total: %0d  Active: %0d",
                     NumberedItem::get_total(), NumberedItem::get_active());
        end

        // --- Singleton ---
        $display("\n=== Singleton Pattern ===\n");
        begin
            ConfigManager cfg1, cfg2;
            cfg1 = ConfigManager::get_inst();
            cfg1.timeout_ns = 5000;
            cfg1.dut_name   = "my_soc";
            cfg1.display();

            cfg2 = ConfigManager::get_inst();
            cfg2.display();  // same values — same instance

            $display("cfg1 == cfg2? %s", (cfg1 == cfg2) ? "YES" : "NO");
        end

        // --- Extern methods ---
        $display("\n=== Extern Methods ===\n");
        begin
            Calculator calc = new();
            $display("5! = %0d",       calc.factorial(5));
            $display("fib(10) = %0d",  calc.fibonacci(10));
            $display("2^10 = %.0f",    calc.power(2.0, 10));
        end

        $finish;
    end
endmodule
