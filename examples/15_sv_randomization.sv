// SystemVerilog Constrained-Random Verification with Classes
// Demonstrates: rand/randc, constraints, inline constraints, rand_mode,
//               constraint_mode, pre/post_randomize, distribution

`timescale 1ns/1ps

// ---------------------------------------------------------------------------
// 1. Basic randomization with constraints
// ---------------------------------------------------------------------------
class EthernetFrame;
    rand  bit [47:0] dst_mac;
    rand  bit [47:0] src_mac;
    rand  bit [15:0] ethertype;
    rand  bit [7:0]  payload[];
    randc bit [2:0]  priority;

    constraint valid_ethertype {
        ethertype inside {16'h0800, 16'h0806, 16'h86DD, 16'h8100};
    }

    constraint payload_size {
        payload.size() inside {[46:1500]};
    }

    constraint typical_payload {
        payload.size() dist {
            [46:64]    := 40,
            [65:512]   := 30,
            [513:1500] := 30
        };
    }

    constraint no_broadcast_src {
        src_mac != 48'hFFFF_FFFF_FFFF;
        src_mac[0] == 0;  // Unicast source
    }

    function void display(string prefix = "");
        $display("%sEthernetFrame: dst=%012h src=%012h type=%04h len=%0d pri=%0d",
                 prefix, dst_mac, src_mac, ethertype, payload.size(), priority);
    endfunction
endclass

// ---------------------------------------------------------------------------
// 2. Advanced constraints — implication, if-else, solve-before
// ---------------------------------------------------------------------------
class BusTransaction;
    typedef enum bit [1:0] {IDLE, READ, WRITE, BURST} op_e;

    rand op_e        operation;
    rand bit [31:0]  address;
    rand bit [31:0]  data;
    rand int unsigned burst_length;
    rand bit [31:0]  burst_data[];
    rand bit [1:0]   size;          // 0=byte, 1=halfword, 2=word

    constraint valid_op {
        operation != IDLE;
    }

    constraint addr_alignment {
        if (size == 2) address[1:0] == 2'b00;
        else if (size == 1) address[0] == 1'b0;
    }

    constraint burst_rules {
        (operation == BURST) -> burst_length inside {[2:16]};
        (operation != BURST) -> burst_length == 0;
        burst_data.size() == burst_length;
    }

    constraint addr_range {
        address inside {[32'h0000_0000 : 32'h0FFF_FFFF]};
    }

    constraint op_distribution {
        operation dist { READ := 40, WRITE := 40, BURST := 20 };
    }

    constraint solve_order {
        solve operation before burst_length;
        solve burst_length before burst_data;
        solve size before address;
    }

    function string op_name();
        case (operation)
            IDLE:  return "IDLE";
            READ:  return "READ";
            WRITE: return "WRITE";
            BURST: return "BURST";
        endcase
    endfunction

    function void display(string prefix = "");
        $display("%s%s addr=0x%08h data=0x%08h size=%0d burst_len=%0d",
                 prefix, op_name(), address, data, size, burst_length);
        if (operation == BURST)
            foreach (burst_data[i])
                $display("%s  burst[%0d] = 0x%08h", prefix, i, burst_data[i]);
    endfunction
endclass

// ---------------------------------------------------------------------------
// 3. pre_randomize and post_randomize callbacks
// ---------------------------------------------------------------------------
class PacketWithChecksum;
    rand bit [7:0]  header;
    rand bit [7:0]  payload[];
    bit [15:0]      checksum;        // Not randomized — computed
    int             randomize_count;

    constraint payload_range {
        payload.size() inside {[1:8]};
    }

    function new();
        randomize_count = 0;
    endfunction

    function void pre_randomize();
        randomize_count++;
    endfunction

    function void post_randomize();
        checksum = header;
        foreach (payload[i])
            checksum += payload[i];
        checksum = ~checksum + 1;  // Two's complement for checksum
    endfunction

    function bit verify_checksum();
        bit [15:0] sum = header;
        foreach (payload[i])
            sum += payload[i];
        sum += checksum;
        return (sum == 0);
    endfunction

    function void display(string prefix = "");
        $display("%sheader=0x%02h payload_len=%0d checksum=0x%04h valid=%0b (rand_count=%0d)",
                 prefix, header, payload.size(), checksum,
                 verify_checksum(), randomize_count);
    endfunction
endclass

// ---------------------------------------------------------------------------
// 4. Inheritance and constraint layering
// ---------------------------------------------------------------------------
class BaseTransaction;
    rand bit [31:0] addr;
    rand bit [31:0] data;

    constraint base_addr {
        addr inside {[32'h0 : 32'hFFFF]};
    }

    function void display(string prefix = "");
        $display("%saddr=0x%08h data=0x%08h", prefix, addr, data);
    endfunction
endclass

class ConstrainedTransaction extends BaseTransaction;
    constraint narrow_addr {
        addr inside {[32'h100 : 32'h1FF]};
    }

    constraint aligned_addr {
        addr[1:0] == 2'b00;
    }
endclass

// ---------------------------------------------------------------------------
// Testbench
// ---------------------------------------------------------------------------
module sv_randomization_tb;

    initial begin
        // --- Basic randomization ---
        $display("\n=== 1. EthernetFrame Randomization ===");
        begin
            EthernetFrame frame = new();

            repeat (5) begin
                if (!frame.randomize())
                    $fatal(1, "Randomization failed");
                frame.display("  ");
            end

            $display("\n  With inline constraint (payload=64, type=0x0800):");
            if (!frame.randomize() with {
                payload.size() == 64;
                ethertype == 16'h0800;
            })
                $fatal(1, "Inline randomization failed");
            frame.display("  ");
        end

        // --- Advanced constraints ---
        $display("\n=== 2. BusTransaction Randomization ===");
        begin
            BusTransaction txn = new();
            int op_counts[BusTransaction::op_e];

            repeat (100) begin
                if (!txn.randomize())
                    $fatal(1, "Randomization failed");
                op_counts[txn.operation]++;
            end

            $display("  Operation distribution over 100 randomizations:");
            $display("    READ:  %0d", op_counts[BusTransaction::READ]);
            $display("    WRITE: %0d", op_counts[BusTransaction::WRITE]);
            $display("    BURST: %0d", op_counts[BusTransaction::BURST]);

            $display("\n  Sample transactions:");
            repeat (5) begin
                if (!txn.randomize())
                    $fatal(1, "Randomization failed");
                txn.display("    ");
            end
        end

        // --- pre/post_randomize ---
        $display("\n=== 3. pre/post_randomize Callbacks ===");
        begin
            PacketWithChecksum pkt = new();

            repeat (5) begin
                if (!pkt.randomize())
                    $fatal(1, "Randomization failed");
                pkt.display("  ");
            end
        end

        // --- rand_mode and constraint_mode ---
        $display("\n=== 4. rand_mode / constraint_mode ===");
        begin
            EthernetFrame frame = new();

            frame.ethertype.rand_mode(0);
            frame.ethertype = 16'h0800;
            if (!frame.randomize())
                $fatal(1, "Randomization failed");
            $display("  Fixed ethertype: 0x%04h", frame.ethertype);

            frame.ethertype.rand_mode(1);
            frame.valid_ethertype.constraint_mode(0);
            if (!frame.randomize())
                $fatal(1, "Randomization failed");
            $display("  Unconstrained ethertype: 0x%04h", frame.ethertype);
        end

        // --- Constraint layering via inheritance ---
        $display("\n=== 5. Constraint Layering ===");
        begin
            BaseTransaction        bt = new();
            ConstrainedTransaction ct = new();

            $display("  Base (addr range 0x0000-0xFFFF):");
            repeat (3) begin
                if (!bt.randomize()) $fatal(1, "Randomization failed");
                bt.display("    ");
            end

            $display("  Constrained (addr range 0x100-0x1FF, word-aligned):");
            repeat (3) begin
                if (!ct.randomize()) $fatal(1, "Randomization failed");
                ct.display("    ");
                if (ct.addr < 32'h100 || ct.addr > 32'h1FF || ct.addr[1:0] != 0)
                    $fatal(1, "Constraint violated!");
            end
        end

        $display("\n=== All randomization tests passed ===\n");
        $finish;
    end

endmodule
