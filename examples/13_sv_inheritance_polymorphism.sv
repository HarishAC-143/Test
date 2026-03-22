// SystemVerilog Inheritance, Polymorphism, and Abstract Classes
// Demonstrates: extends, super, virtual methods, dynamic dispatch,
//               abstract classes (virtual class), pure virtual methods,
//               casting with $cast

`timescale 1ns/1ps

// ---------------------------------------------------------------------------
// 1. Base class
// ---------------------------------------------------------------------------
class Transaction;
    bit [31:0] addr;
    bit [31:0] data;
    bit [3:0]  id;

    function new(bit [31:0] addr = 0, bit [31:0] data = 0, bit [3:0] id = 0);
        this.addr = addr;
        this.data = data;
        this.id   = id;
    endfunction

    virtual function void display();
        $display("  [Transaction] id=%0d addr=0x%08h data=0x%08h", id, addr, data);
    endfunction

    virtual function string get_type_name();
        return "Transaction";
    endfunction
endclass

// ---------------------------------------------------------------------------
// 2. Derived classes
// ---------------------------------------------------------------------------
class WriteTransaction extends Transaction;
    bit [3:0] byte_enable;

    function new(bit [31:0] addr = 0, bit [31:0] data = 0,
                 bit [3:0] id = 0, bit [3:0] be = 4'hF);
        super.new(addr, data, id);
        this.byte_enable = be;
    endfunction

    virtual function void display();
        $display("  [WriteTransaction] id=%0d addr=0x%08h data=0x%08h be=%04b",
                 id, addr, data, byte_enable);
    endfunction

    virtual function string get_type_name();
        return "WriteTransaction";
    endfunction
endclass

class ReadTransaction extends Transaction;
    int latency_cycles;

    function new(bit [31:0] addr = 0, bit [3:0] id = 0);
        super.new(addr, 0, id);
        latency_cycles = 0;
    endfunction

    virtual function void display();
        $display("  [ReadTransaction] id=%0d addr=0x%08h latency=%0d",
                 id, addr, latency_cycles);
    endfunction

    virtual function string get_type_name();
        return "ReadTransaction";
    endfunction
endclass

class BurstWriteTransaction extends WriteTransaction;
    int burst_length;
    bit [31:0] burst_data[];

    function new(bit [31:0] addr = 0, bit [3:0] id = 0, int burst_len = 4);
        super.new(addr, 0, id);
        burst_length = burst_len;
        burst_data   = new[burst_len];
    endfunction

    virtual function void display();
        $display("  [BurstWriteTransaction] id=%0d addr=0x%08h burst_len=%0d",
                 id, addr, burst_length);
        foreach (burst_data[i])
            $display("    data[%0d] = 0x%08h", i, burst_data[i]);
    endfunction

    virtual function string get_type_name();
        return "BurstWriteTransaction";
    endfunction
endclass

// ---------------------------------------------------------------------------
// 3. Abstract class with pure virtual methods
// ---------------------------------------------------------------------------
virtual class ProtocolChecker;
    pure virtual function bit check(Transaction txn);
    pure virtual function string protocol_name();

    function void report(Transaction txn);
        if (check(txn))
            $display("  [%s] PASS: %s id=%0d", protocol_name(),
                     txn.get_type_name(), txn.id);
        else
            $display("  [%s] FAIL: %s id=%0d", protocol_name(),
                     txn.get_type_name(), txn.id);
    endfunction
endclass

class AHBChecker extends ProtocolChecker;
    virtual function bit check(Transaction txn);
        return (txn.addr[1:0] == 2'b00);  // Word-aligned
    endfunction

    virtual function string protocol_name();
        return "AHB";
    endfunction
endclass

class AXIChecker extends ProtocolChecker;
    virtual function bit check(Transaction txn);
        return (txn.addr < 32'h1000_0000);  // Must be in lower 256MB
    endfunction

    virtual function string protocol_name();
        return "AXI";
    endfunction
endclass

// ---------------------------------------------------------------------------
// Testbench
// ---------------------------------------------------------------------------
module sv_inheritance_tb;

    initial begin
        // --- Polymorphism with virtual methods ---
        $display("\n=== 1. Polymorphism (virtual methods) ===");
        begin
            Transaction txns[4];
            WriteTransaction      wt;
            ReadTransaction       rt;
            BurstWriteTransaction bt;

            txns[0] = new(32'h0000_1000, 32'hAAAA_BBBB, 0);

            wt = new(32'h0000_2000, 32'hCCCC_DDDD, 1, 4'b1100);
            txns[1] = wt;

            rt = new(32'h0000_3000, 2);
            rt.latency_cycles = 5;
            txns[2] = rt;

            bt = new(32'h0000_4000, 3, 3);
            bt.burst_data[0] = 32'h1111;
            bt.burst_data[1] = 32'h2222;
            bt.burst_data[2] = 32'h3333;
            txns[3] = bt;

            foreach (txns[i]) begin
                $display("  Type: %s", txns[i].get_type_name());
                txns[i].display();
            end
        end

        // --- $cast for downcasting ---
        $display("\n=== 2. Downcasting with $cast ===");
        begin
            Transaction base_handle;
            WriteTransaction derived_handle;

            base_handle = new WriteTransaction(32'hBEEF, 32'hFACE, 5, 4'hA);

            if ($cast(derived_handle, base_handle)) begin
                $display("  Cast succeeded, byte_enable = %04b",
                         derived_handle.byte_enable);
            end else begin
                $display("  Cast failed");
            end

            base_handle = new ReadTransaction(32'h1234, 6);
            if (!$cast(derived_handle, base_handle))
                $display("  Cast to WriteTransaction correctly failed for ReadTransaction");
        end

        // --- Abstract classes and pure virtual methods ---
        $display("\n=== 3. Abstract Classes ===");
        begin
            ProtocolChecker checkers[2];
            Transaction     test_txns[4];

            checkers[0] = new AHBChecker();
            checkers[1] = new AXIChecker();

            test_txns[0] = new(32'h0000_1000, 32'hAAAA, 0); // Aligned, < 256MB
            test_txns[1] = new(32'h0000_1001, 32'hBBBB, 1); // Unaligned
            test_txns[2] = new(32'h2000_0000, 32'hCCCC, 2); // > 256MB
            test_txns[3] = new(32'h0000_0004, 32'hDDDD, 3); // Aligned, < 256MB

            foreach (checkers[c])
                foreach (test_txns[t])
                    checkers[c].report(test_txns[t]);
        end

        $display("\n=== All inheritance/polymorphism tests passed ===\n");
        $finish;
    end

endmodule
