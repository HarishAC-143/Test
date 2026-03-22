// =============================================================================
// Example 03: Randomization and Constraints
// Covers: rand/randc, constraint blocks, distribution, implication,
//         solve-before, inline constraints, constraint_mode, rand_mode,
//         pre/post_randomize, and constraint patterns
// =============================================================================

class EthernetFrame;
  rand  bit [47:0] dst_mac;
  rand  bit [47:0] src_mac;
  rand  bit [15:0] eth_type;
  rand  bit [7:0]  payload[];
  rand  bit [2:0]  vlan_priority;
  randc bit [3:0]  sequence_num;

  constraint c_payload_size {
    payload.size() inside {[46:1500]};
  }

  constraint c_eth_type {
    eth_type inside {16'h0800, 16'h0806, 16'h86DD, 16'h8100};
  }

  constraint c_unicast_dst {
    dst_mac[0] == 1'b0;
  }

  constraint c_no_broadcast_src {
    src_mac != 48'hFFFF_FFFF_FFFF;
  }

  bit [31:0] crc;

  function new();
  endfunction

  function void post_randomize();
    crc = 0;
    foreach (payload[i])
      crc = crc ^ {24'h0, payload[i]};
    crc = crc ^ dst_mac[31:0] ^ src_mac[31:0];
  endfunction

  function void display();
    $display("Ethernet Frame:");
    $display("  DST: %012h  SRC: %012h", dst_mac, src_mac);
    $display("  Type: 0x%04h  Payload: %0d bytes  Priority: %0d  Seq: %0d",
             eth_type, payload.size(), vlan_priority, sequence_num);
    $display("  CRC: 0x%08h", crc);
  endfunction
endclass


class MemoryTransaction;
  rand bit [31:0]  addr;
  rand bit [31:0]  data;
  rand int         delay;
  rand bit         is_write;
  rand bit [2:0]   burst_type;
  rand int         burst_len;

  constraint c_addr_aligned {
    addr[1:0] == 2'b00;
  }

  constraint c_addr_range {
    addr inside {[32'h0000_0000 : 32'h0000_FFFF]};
  }

  // Implication: writes must have non-zero data
  constraint c_write_data {
    is_write -> data != 0;
  }

  // Distribution: bias toward small delays
  constraint c_delay_dist {
    delay dist {
      0       := 30,
      [1:5]   := 40,
      [6:20]  := 20,
      [21:50] := 10
    };
  }

  // Conditional constraint
  constraint c_burst {
    if (burst_type == 0) {
      burst_len == 1;
    } else if (burst_type == 1) {
      burst_len inside {[2:16]};
    } else {
      burst_len inside {2, 4, 8, 16};
    }
  }

  // Solve ordering: decide write/read first, then constrain data
  constraint c_solve_order {
    solve is_write before data;
    solve burst_type before burst_len;
  }

  function void display();
    $display("  %s addr=0x%08h data=0x%08h delay=%0d burst_type=%0d burst_len=%0d",
             is_write ? "WR" : "RD", addr, data, delay, burst_type, burst_len);
  endfunction
endclass


class ConstrainedPacket;
  rand bit [7:0] header;
  rand bit [7:0] payload[];
  rand bit [7:0] footer;

  constraint c_size {
    payload.size() inside {[4:16]};
  }

  constraint c_header_footer {
    header == 8'hAA;
    footer == 8'h55;
  }

  constraint c_payload_ordered {
    foreach (payload[i])
      if (i > 0)
        payload[i] >= payload[i-1];
  }

  constraint c_payload_range {
    foreach (payload[i])
      payload[i] inside {[8'h10:8'hF0]};
  }

  function void display();
    string s = $sformatf("Pkt [0x%02h] ", header);
    foreach (payload[i])
      s = {s, $sformatf("%02h ", payload[i])};
    s = {s, $sformatf("[0x%02h]", footer)};
    $display(s);
  endfunction
endclass


module tb_randomization;
  initial begin
    $display("\n=== Part 1: Basic Randomization ===");
    begin
      EthernetFrame eth = new();
      repeat (3) begin
        if (!eth.randomize())
          $fatal(1, "Randomization failed");
        eth.display();
        $display("");
      end
    end

    $display("\n=== Part 2: randc (Cyclic Randomization) ===");
    begin
      EthernetFrame eth = new();
      $display("Sequence numbers (randc — each value before repeat):");
      $write("  ");
      repeat (16) begin
        void'(eth.randomize());
        $write("%0d ", eth.sequence_num);
      end
      $display("");
    end

    $display("\n=== Part 3: Inline Constraints ===");
    begin
      MemoryTransaction mtxn = new();

      $display("Constrained to writes at addr 0x1000:");
      repeat (3) begin
        if (!mtxn.randomize() with {
          addr == 32'h0000_1000;
          is_write == 1;
        })
          $fatal(1, "Randomization failed");
        mtxn.display();
      end

      $display("\nConstrained to reads with zero delay:");
      repeat (3) begin
        if (!mtxn.randomize() with {
          is_write == 0;
          delay == 0;
        })
          $fatal(1, "Randomization failed");
        mtxn.display();
      end
    end

    $display("\n=== Part 4: constraint_mode() and rand_mode() ===");
    begin
      MemoryTransaction mtxn = new();

      mtxn.c_addr_range.constraint_mode(0);
      void'(mtxn.randomize());
      $display("With c_addr_range disabled:");
      mtxn.display();

      mtxn.c_addr_range.constraint_mode(1);

      mtxn.addr.rand_mode(0);
      mtxn.addr = 32'h0000_ABCD;
      void'(mtxn.randomize());
      $display("With addr.rand_mode(0), fixed addr:");
      mtxn.display();
      mtxn.addr.rand_mode(1);
    end

    $display("\n=== Part 5: Distribution Analysis ===");
    begin
      MemoryTransaction mtxn = new();
      int delay_bins[4] = '{0, 0, 0, 0};

      repeat (1000) begin
        void'(mtxn.randomize());
        case (1)
          (mtxn.delay == 0):           delay_bins[0]++;
          (mtxn.delay inside {[1:5]}):  delay_bins[1]++;
          (mtxn.delay inside {[6:20]}): delay_bins[2]++;
          default:                      delay_bins[3]++;
        endcase
      end

      $display("Delay distribution over 1000 randomizations:");
      $display("  delay=0:     %0d (expected ~30%%)", delay_bins[0]);
      $display("  delay=1-5:   %0d (expected ~40%%)", delay_bins[1]);
      $display("  delay=6-20:  %0d (expected ~20%%)", delay_bins[2]);
      $display("  delay=21-50: %0d (expected ~10%%)", delay_bins[3]);
    end

    $display("\n=== Part 6: Ordered Array Constraint ===");
    begin
      ConstrainedPacket cpkt = new();
      repeat (3) begin
        void'(cpkt.randomize());
        cpkt.display();
      end
    end

    $display("\n=== Part 7: Randomization with pre/post_randomize ===");
    begin
      EthernetFrame eth = new();
      void'(eth.randomize());
      $display("Post-randomize computed CRC: 0x%08h", eth.crc);
    end
  end
endmodule
