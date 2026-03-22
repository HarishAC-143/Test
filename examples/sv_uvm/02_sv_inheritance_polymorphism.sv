// =============================================================================
// SystemVerilog Inheritance, Polymorphism, and Abstract Classes
// =============================================================================
//
// Demonstrates:
//   - Single inheritance with 'extends'
//   - The 'super' keyword
//   - Virtual methods and dynamic dispatch
//   - Abstract (pure virtual) classes
//   - $cast for safe downcasting

// ---- Base transaction hierarchy ----
class BaseTransaction;
    bit [31:0] address;
    bit [31:0] data;
    bit        write;
    int        id;

    static int next_id = 0;

    function new();
        id = next_id++;
    endfunction

    virtual function void display();
        $display("[BaseTransaction #%0d] addr=0x%08h data=0x%08h %s",
                 id, address, data, write ? "WRITE" : "READ");
    endfunction

    virtual function string get_type_name();
        return "BaseTransaction";
    endfunction
endclass

class BurstTransaction extends BaseTransaction;
    int       burst_length;
    bit [2:0] burst_type;
    bit [31:0] data_array[];

    function new(int blen = 1);
        super.new();
        burst_length = blen;
        burst_type   = 3'b001;  // INCR
        data_array   = new[burst_length];
    endfunction

    virtual function void display();
        super.display();
        $display("  Burst: length=%0d type=%03b", burst_length, burst_type);
        foreach (data_array[i])
            $display("    [%0d] = 0x%08h", i, data_array[i]);
    endfunction

    virtual function string get_type_name();
        return "BurstTransaction";
    endfunction
endclass

class CacheableTransaction extends BurstTransaction;
    bit cacheable;
    bit bufferable;
    bit [3:0] cache_attr;

    function new(int blen = 1);
        super.new(blen);
        cacheable  = 1;
        bufferable = 1;
    endfunction

    virtual function void display();
        super.display();
        $display("  Cache: cacheable=%0b bufferable=%0b attr=0x%01h",
                 cacheable, bufferable, cache_attr);
    endfunction

    virtual function string get_type_name();
        return "CacheableTransaction";
    endfunction
endclass

// ---- Abstract class with pure virtual methods ----
virtual class ProtocolChecker;
    string protocol_name;

    function new(string name);
        protocol_name = name;
    endfunction

    pure virtual function bit check_address(bit [31:0] addr);
    pure virtual function bit check_data(bit [31:0] data);
    pure virtual function void report();
endclass

class APBChecker extends ProtocolChecker;
    int violations;

    function new();
        super.new("APB");
        violations = 0;
    endfunction

    virtual function bit check_address(bit [31:0] addr);
        // APB addresses must be word-aligned
        if (addr[1:0] != 0) begin
            $display("[APB] Address alignment violation: 0x%08h", addr);
            violations++;
            return 0;
        end
        return 1;
    endfunction

    virtual function bit check_data(bit [31:0] data);
        return 1;  // APB has no data restrictions
    endfunction

    virtual function void report();
        $display("[APB Checker] Total violations: %0d", violations);
    endfunction
endclass

class AXIChecker extends ProtocolChecker;
    int violations;
    int transactions_checked;

    function new();
        super.new("AXI");
        violations = 0;
        transactions_checked = 0;
    endfunction

    virtual function bit check_address(bit [31:0] addr);
        transactions_checked++;
        // AXI burst transfers must not cross 4KB boundary
        if ((addr & 32'hFFFFF000) != ((addr + 32'd4095) & 32'hFFFFF000)) begin
            $display("[AXI] 4KB boundary crossing at 0x%08h", addr);
            violations++;
            return 0;
        end
        return 1;
    endfunction

    virtual function bit check_data(bit [31:0] data);
        transactions_checked++;
        return 1;
    endfunction

    virtual function void report();
        $display("[AXI Checker] Checked: %0d  Violations: %0d",
                 transactions_checked, violations);
    endfunction
endclass

// ---- Testbench ----
module tb_inheritance;
    initial begin
        BaseTransaction base_tr;
        BurstTransaction burst_tr;
        CacheableTransaction cache_tr;

        $display("=== Inheritance Chain Demo ===\n");

        base_tr = new();
        base_tr.address = 32'h0000_1000;
        base_tr.data    = 32'hCAFE_BABE;
        base_tr.write   = 1;
        base_tr.display();

        $display("");

        burst_tr = new(4);
        burst_tr.address = 32'h0000_2000;
        burst_tr.write   = 1;
        foreach (burst_tr.data_array[i])
            burst_tr.data_array[i] = i * 32'h1111_1111;
        burst_tr.display();

        $display("");

        cache_tr = new(2);
        cache_tr.address   = 32'h0000_3000;
        cache_tr.write     = 0;
        cache_tr.cache_attr = 4'hF;
        cache_tr.data_array[0] = 32'hAAAA_BBBB;
        cache_tr.data_array[1] = 32'hCCCC_DDDD;
        cache_tr.display();

        // --- Polymorphism demo ---
        $display("\n=== Polymorphism Demo ===\n");
        begin
            BaseTransaction handles[$];
            handles.push_back(base_tr);
            handles.push_back(burst_tr);
            handles.push_back(cache_tr);

            foreach (handles[i]) begin
                $display("--- handles[%0d] type: %s ---", i, handles[i].get_type_name());
                handles[i].display();
                $display("");
            end
        end

        // --- $cast demo ---
        $display("=== $cast Demo ===\n");
        begin
            BaseTransaction parent_handle = cache_tr;
            BurstTransaction downcast_burst;
            CacheableTransaction downcast_cache;

            if ($cast(downcast_burst, parent_handle))
                $display("Cast to BurstTransaction: OK (type=%s)",
                         downcast_burst.get_type_name());

            if ($cast(downcast_cache, parent_handle))
                $display("Cast to CacheableTransaction: OK (cache_attr=0x%01h)",
                         downcast_cache.cache_attr);

            // This will fail: base_tr doesn't point to a BurstTransaction
            if (!$cast(downcast_burst, base_tr))
                $display("Cast base_tr to BurstTransaction: FAILED (expected)");
        end

        // --- Abstract class / Protocol checker demo ---
        $display("\n=== Abstract Class Demo ===\n");
        begin
            ProtocolChecker checkers[$];
            APBChecker apb_chk = new();
            AXIChecker axi_chk = new();

            checkers.push_back(apb_chk);
            checkers.push_back(axi_chk);

            // Run checks through polymorphic handles
            foreach (checkers[i]) begin
                void'(checkers[i].check_address(32'h0000_1000));   // aligned
                void'(checkers[i].check_address(32'h0000_1001));   // unaligned
                void'(checkers[i].check_address(32'h0000_0FF0));   // near 4KB boundary
                checkers[i].report();
                $display("");
            end
        end

        $finish;
    end
endmodule
