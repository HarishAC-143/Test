// =============================================================================
// SystemVerilog Constrained-Random Verification (CRV)
// =============================================================================
//
// Demonstrates:
//   - rand and randc variables
//   - Constraint blocks: range, implication, distribution, solve-before
//   - Soft constraints
//   - Inline constraints with 'randomize() with {}'
//   - constraint_mode() and rand_mode()
//   - pre_randomize() and post_randomize() callbacks
//   - Randomizing arrays

class EthernetFrame;
    rand  bit [47:0] dst_mac;
    rand  bit [47:0] src_mac;
    rand  bit [15:0] ethertype;
    rand  bit [7:0]  payload[];
    randc bit [2:0]  priority;

    // Size constraint: valid Ethernet payload
    constraint payload_size_c {
        payload.size() inside {[46:1500]};
    }

    // Common ethertype values
    constraint ethertype_c {
        ethertype dist {
            16'h0800 := 60,    // IPv4 (60% weight)
            16'h86DD := 20,    // IPv6
            16'h0806 := 10,    // ARP
            16'h8100 := 10     // VLAN
        };
    }

    // Broadcast/unicast distribution
    constraint mac_type_c {
        dst_mac[0] dist { 0 := 80, 1 := 20 };  // 80% unicast, 20% multicast
    }

    // Soft constraint: default small payloads (can be overridden)
    constraint soft_size_c {
        soft payload.size() < 100;
    }

    bit [31:0] fcs;

    function new();
    endfunction

    function void post_randomize();
        // Compute FCS after randomization
        fcs = 32'hFFFF_FFFF;
        fcs ^= dst_mac[31:0] ^ {16'h0, dst_mac[47:32]};
        fcs ^= src_mac[31:0] ^ {16'h0, src_mac[47:32]};
        fcs ^= {16'h0, ethertype};
        foreach (payload[i])
            fcs ^= {24'h0, payload[i]};
    endfunction

    function void display();
        $display("[EthernetFrame]");
        $display("  DST: %012h  SRC: %012h", dst_mac, src_mac);
        $display("  EtherType: 0x%04h  Priority: %0d", ethertype, priority);
        $display("  Payload: %0d bytes  FCS: 0x%08h", payload.size(), fcs);
    endfunction
endclass

class AXITransaction;
    rand bit [31:0] addr;
    rand bit [3:0]  id;
    rand bit [7:0]  len;        // burst_length - 1
    rand bit [2:0]  size;       // 2^size bytes per beat
    rand bit [1:0]  burst;      // 0=FIXED, 1=INCR, 2=WRAP
    rand bit        write;
    rand bit [31:0] data[];
    rand bit [3:0]  strb[];

    // Basic range constraints
    constraint id_c {
        id inside {[0:7]};
    }

    constraint size_c {
        size inside {[0:2]};   // up to 4-byte transfers
    }

    constraint burst_c {
        burst inside {0, 1, 2};  // valid burst types only
    }

    // WRAP bursts have restricted lengths
    constraint wrap_len_c {
        (burst == 2) -> len inside {1, 3, 7, 15};
    }

    // FIXED bursts limited to 16 beats
    constraint fixed_len_c {
        (burst == 0) -> len inside {[0:15]};
    }

    // Address alignment
    constraint alignment_c {
        addr % (1 << size) == 0;
    }

    // 4KB boundary rule: burst must not cross a 4KB boundary
    constraint boundary_c {
        (burst == 1) -> (
            ((addr + (len + 1) * (1 << size)) & 32'hFFFFF000) ==
            (addr & 32'hFFFFF000) ||
            len < 4
        );
    }

    // Data array matches burst length
    constraint data_array_c {
        data.size() == len + 1;
        strb.size() == len + 1;
    }

    // Write distribution
    constraint write_dist_c {
        write dist { 1 := 60, 0 := 40 };
    }

    // Strobe validity: all ones for writes
    constraint strb_c {
        foreach (strb[i])
            write -> (strb[i] == 4'hF);
    }

    function new();
    endfunction

    function void display();
        $display("[AXI %s] ID=%0d ADDR=0x%08h LEN=%0d SIZE=%0d BURST=%s",
                 write ? "WR" : "RD", id, addr, len, size,
                 (burst == 0) ? "FIXED" : (burst == 1) ? "INCR" : "WRAP");
        if (write)
            foreach (data[i])
                $display("  beat[%0d]: data=0x%08h strb=0x%01h", i, data[i], strb[i]);
    endfunction
endclass

// ---- pre_randomize / post_randomize example ----
class TimestampedPacket;
    rand bit [15:0] seq_num;
    rand bit [31:0] payload;
    int             timestamp;
    bit [7:0]       checksum;

    static int next_seq = 0;

    function void pre_randomize();
        timestamp = $time;
    endfunction

    function void post_randomize();
        checksum = seq_num[7:0] ^ seq_num[15:8] ^
                   payload[7:0] ^ payload[15:8] ^
                   payload[23:16] ^ payload[31:24];
        next_seq++;
    endfunction

    function void display();
        $display("[Pkt] seq=%0d payload=0x%08h time=%0t chk=0x%02h",
                 seq_num, payload, timestamp, checksum);
    endfunction
endclass

module tb_randomization;
    initial begin
        // --- EthernetFrame ---
        $display("=== Ethernet Frame Randomization ===\n");
        begin
            EthernetFrame frame = new();

            repeat (3) begin
                if (!frame.randomize())
                    $error("Randomization failed");
                frame.display();
                $display("");
            end

            // Inline constraints override soft constraint
            $display("--- With inline constraints (large payload) ---");
            if (!frame.randomize() with {
                payload.size() inside {[1000:1500]};
                ethertype == 16'h0800;
            })
                $error("Constrained randomization failed");
            frame.display();
        end

        // --- AXI Transaction ---
        $display("\n=== AXI Transaction Randomization ===\n");
        begin
            AXITransaction axi = new();

            repeat (5) begin
                if (!axi.randomize())
                    $error("AXI randomization failed");
                axi.display();
                $display("");
            end

            // rand_mode / constraint_mode
            $display("--- Forcing specific values ---");
            axi.addr.rand_mode(0);
            axi.addr = 32'h0000_1000;
            axi.write_dist_c.constraint_mode(0);  // disable distribution
            if (!axi.randomize() with { write == 1; len == 3; burst == 1; })
                $error("Constrained randomization failed");
            axi.display();

            // Re-enable
            axi.addr.rand_mode(1);
            axi.write_dist_c.constraint_mode(1);
        end

        // --- randc demonstration ---
        $display("\n=== randc (Cyclic Random) ===\n");
        begin
            EthernetFrame frame = new();
            $display("Priority values (randc — no repeats until cycle exhausts):");
            repeat (16) begin
                void'(frame.randomize());
                $write("%0d ", frame.priority);
            end
            $display("");
        end

        // --- pre/post_randomize ---
        $display("\n=== Pre/Post Randomize ===\n");
        begin
            TimestampedPacket pkt = new();
            repeat (3) begin
                #10;
                void'(pkt.randomize());
                pkt.display();
            end
        end

        $finish;
    end
endmodule
