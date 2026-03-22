// =============================================================================
// SystemVerilog Class Basics — Constructors, Properties, Methods, Encapsulation
// =============================================================================
//
// Demonstrates:
//   - Class definition and object allocation
//   - Constructors with arguments and defaults
//   - The 'this' keyword
//   - Access control: local, protected, public (default)
//   - Functions vs tasks in classes

// ---- Basic class with constructor and methods ----
class Packet;
    bit [7:0]  src_addr;
    bit [7:0]  dst_addr;
    bit [31:0] payload;
    bit [15:0] crc;

    function new(bit [7:0] src = 0, bit [7:0] dst = 0);
        this.src_addr = src;
        this.dst_addr = dst;
        this.payload  = 0;
        this.crc      = 0;
    endfunction

    function void compute_crc();
        crc = src_addr ^ dst_addr ^ payload[15:0] ^ payload[31:16];
    endfunction

    function void display();
        $display("[Packet] src=0x%02h dst=0x%02h payload=0x%08h crc=0x%04h",
                 src_addr, dst_addr, payload, crc);
    endfunction
endclass

// ---- Access control demonstration ----
class BankAccount;
    local    int balance;           // only accessible inside BankAccount
    protected string owner;         // accessible in subclasses too
    int account_number;             // public (default)

    function new(string owner, int account_number, int initial_balance = 0);
        this.owner          = owner;
        this.account_number = account_number;
        this.balance        = initial_balance;
    endfunction

    function int get_balance();
        return balance;
    endfunction

    function bit deposit(int amount);
        if (amount <= 0) return 0;
        balance += amount;
        return 1;
    endfunction

    function bit withdraw(int amount);
        if (amount <= 0 || amount > balance) return 0;
        balance -= amount;
        return 1;
    endfunction

    function void display();
        $display("[Account #%0d] Owner: %s  Balance: $%0d",
                 account_number, owner, balance);
    endfunction
endclass

class SavingsAccount extends BankAccount;
    int interest_rate_bps;  // basis points (100 = 1%)

    function new(string owner, int acct_num, int initial, int rate_bps = 200);
        super.new(owner, acct_num, initial);
        interest_rate_bps = rate_bps;
    endfunction

    function void apply_interest();
        int current = get_balance();
        int interest = current * interest_rate_bps / 10000;
        if (interest > 0) deposit(interest);
        // Note: 'owner' is accessible here (protected), but 'balance' is not (local)
        $display("[Savings] %s earned $%0d interest", owner, interest);
    endfunction
endclass

// ---- Task vs function in classes ----
class BusInterface;
    int clk_period = 10;

    function bit [31:0] pack_data(bit [15:0] high, bit [15:0] low);
        return {high, low};
    endfunction

    task wait_cycles(int n);
        repeat (n) #(clk_period);
    endtask
endclass

// ---- Testbench ----
module tb_class_basics;
    initial begin
        // --- Packet demo ---
        Packet p1, p2;

        p1 = new(8'hA5, 8'h3C);
        p1.payload = 32'hDEAD_BEEF;
        p1.compute_crc();
        p1.display();

        p2 = new();
        p2.src_addr = 8'h01;
        p2.dst_addr = 8'h02;
        p2.payload  = 32'h1234_5678;
        p2.compute_crc();
        p2.display();

        $display("\n--- Bank Account demo ---");

        // --- BankAccount demo ---
        begin
            BankAccount    checking;
            SavingsAccount savings;

            checking = new("Alice", 1001, 5000);
            checking.display();
            checking.deposit(1500);
            checking.withdraw(200);
            checking.display();

            savings = new("Bob", 2001, 10000, 500);
            savings.display();
            savings.apply_interest();
            savings.display();
        end

        $display("\n--- Task demo ---");

        // --- Task demo ---
        begin
            BusInterface bus = new();
            bit [31:0] packed;
            packed = bus.pack_data(16'hABCD, 16'hEF01);
            $display("Packed data: 0x%08h", packed);

            $display("Waiting 3 cycles at time %0t", $time);
            bus.wait_cycles(3);
            $display("Done waiting at time %0t", $time);
        end

        $finish;
    end
endmodule
