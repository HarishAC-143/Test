// =============================================================================
// Example 03: Parameterized Classes, Constraints, and Randomization
// Demonstrates: type parameters, value parameters, constraint blocks,
//               inline constraints, rand_mode, constraint_mode,
//               pre_randomize, post_randomize, distributions.
// =============================================================================

// --- Parameterized FIFO ---
class FIFO #(type T = int, int DEPTH = 8);
  local T storage[$];

  function void push(T item);
    if (storage.size() >= DEPTH) begin
      $display("FIFO overflow — dropping oldest item");
      void'(storage.pop_front());
    end
    storage.push_back(item);
  endfunction

  function T pop();
    if (storage.size() == 0) begin
      $fatal(1, "FIFO underflow");
    end
    return storage.pop_front();
  endfunction

  function T peek();
    if (storage.size() == 0)
      $fatal(1, "FIFO peek on empty");
    return storage[0];
  endfunction

  function int size();
    return storage.size();
  endfunction

  function bit is_empty();
    return (storage.size() == 0);
  endfunction

  function bit is_full();
    return (storage.size() >= DEPTH);
  endfunction

  function void flush();
    storage.delete();
  endfunction
endclass

// --- Parameterized Stack ---
class Stack #(type T = int, int MAX_DEPTH = 16);
  local T data[$];

  function void push(T item);
    if (data.size() >= MAX_DEPTH)
      $error("Stack overflow");
    else
      data.push_back(item);
  endfunction

  function T pop();
    if (data.size() == 0)
      $fatal(1, "Stack underflow");
    return data.pop_back();
  endfunction

  function T top();
    if (data.size() == 0)
      $fatal(1, "Stack top on empty");
    return data[data.size()-1];
  endfunction

  function int depth();
    return data.size();
  endfunction

  function bit is_empty();
    return (data.size() == 0);
  endfunction
endclass

// --- Parameterized Scoreboard ---
class Scoreboard #(type T = int);
  local T expected_q[$];
  local T actual_q[$];
  int unsigned matches;
  int unsigned mismatches;

  function new();
    matches    = 0;
    mismatches = 0;
  endfunction

  function void add_expected(T item);
    expected_q.push_back(item);
  endfunction

  function void add_actual(T item);
    actual_q.push_back(item);
  endfunction

  function void check();
    while (expected_q.size() > 0 && actual_q.size() > 0) begin
      T exp = expected_q.pop_front();
      T act = actual_q.pop_front();
      if (exp == act) begin
        matches++;
      end else begin
        mismatches++;
        $display("MISMATCH: expected=%p actual=%p", exp, act);
      end
    end
  endfunction

  function void report();
    $display("Scoreboard: matches=%0d mismatches=%0d pending_exp=%0d pending_act=%0d",
             matches, mismatches, expected_q.size(), actual_q.size());
  endfunction
endclass

// --- Constrained Randomization ---
typedef enum bit [1:0] {
  OP_READ  = 2'b00,
  OP_WRITE = 2'b01,
  OP_RMW   = 2'b10,
  OP_IDLE  = 2'b11
} operation_e;

class AXI_Transaction;
  rand bit [31:0]    addr;
  rand bit [31:0]    data;
  rand operation_e   op;
  rand bit [7:0]     burst_len;
  rand bit [2:0]     burst_size;
  rand bit [1:0]     burst_type;
  rand bit [3:0]     strobe;
  randc bit [3:0]    id;              // cyclic: exhausts all values before repeating
       bit [31:0]    response_data;
       bit [1:0]     response;
       bit [15:0]    checksum;

  // Alignment constraint
  constraint c_aligned {
    burst_size == 3'b010 -> addr[1:0] == 2'b00;
    burst_size == 3'b001 -> addr[0]   == 1'b0;
  }

  // Burst type constraints
  constraint c_burst_type {
    burst_type inside {0, 1, 2};
    burst_type == 0 -> burst_len == 0;
    burst_type == 2 -> burst_len inside {1, 3, 7, 15};
  }

  // Operation-dependent constraints
  constraint c_op_rules {
    op == OP_READ  -> strobe == 4'h0;
    op == OP_WRITE -> strobe != 4'h0;
    op == OP_IDLE  -> (addr == 0 && data == 0);
  }

  // Distribution
  constraint c_op_dist {
    op dist {
      OP_READ  := 40,
      OP_WRITE := 40,
      OP_RMW   := 15,
      OP_IDLE  := 5
    };
  }

  // Address range
  constraint c_addr_range {
    addr inside {[32'h0000_0000:32'h0000_FFFF],
                 [32'h1000_0000:32'h1000_FFFF]};
  }

  function new();
  endfunction

  function void pre_randomize();
    // hook before randomization
  endfunction

  function void post_randomize();
    checksum = 0;
    checksum = addr[15:0] ^ addr[31:16] ^ data[15:0] ^ data[31:16] ^
               {14'b0, op} ^ {8'b0, burst_len} ^ {12'b0, strobe};
  endfunction

  function void display();
    $display("AXI [ID=%0d] %s addr=0x%08h data=0x%08h burst=%0d×%0d type=%0d strobe=0x%h chksum=0x%04h",
             id, op.name(), addr, data, burst_len+1, (1 << burst_size),
             burst_type, strobe, checksum);
  endfunction
endclass

// --- Testbench ---
module tb_parameterized;
  initial begin
    // ---- Parameterized FIFO ----
    $display("\n===== Parameterized FIFO =====");
    FIFO #(bit [31:0], 4) data_fifo = new();
    FIFO #(string, 3)     name_fifo = new();

    data_fifo.push(32'hAAAA_AAAA);
    data_fifo.push(32'hBBBB_BBBB);
    data_fifo.push(32'hCCCC_CCCC);
    $display("Data FIFO size: %0d, full: %0b", data_fifo.size(), data_fifo.is_full());
    data_fifo.push(32'hDDDD_DDDD);
    $display("Data FIFO size: %0d, full: %0b", data_fifo.size(), data_fifo.is_full());
    $display("Pop: 0x%08h", data_fifo.pop());
    $display("Pop: 0x%08h", data_fifo.pop());

    name_fifo.push("alpha");
    name_fifo.push("bravo");
    name_fifo.push("charlie");
    $display("Name FIFO: %s", name_fifo.pop());

    // ---- Parameterized Stack ----
    $display("\n===== Parameterized Stack =====");
    Stack #(int, 8) int_stack = new();
    int_stack.push(10);
    int_stack.push(20);
    int_stack.push(30);
    $display("Stack top: %0d depth: %0d", int_stack.top(), int_stack.depth());
    $display("Pop: %0d", int_stack.pop());
    $display("Pop: %0d", int_stack.pop());
    $display("Stack depth: %0d", int_stack.depth());

    // ---- Parameterized Scoreboard ----
    $display("\n===== Parameterized Scoreboard =====");
    Scoreboard #(bit [31:0]) scb = new();
    scb.add_expected(32'h1111);
    scb.add_expected(32'h2222);
    scb.add_expected(32'h3333);
    scb.add_actual(32'h1111);
    scb.add_actual(32'h2222);
    scb.add_actual(32'hFFFF);
    scb.check();
    scb.report();

    // ---- Constrained Randomization ----
    $display("\n===== Constrained Randomization =====");
    AXI_Transaction txn = new();

    $display("\n--- 10 random transactions ---");
    repeat (10) begin
      if (!txn.randomize())
        $fatal(1, "Randomization failed");
      txn.display();
    end

    // ---- Inline Constraints ----
    $display("\n--- Inline constraint: writes only, addr in 0x1000_xxxx ---");
    repeat (5) begin
      if (!txn.randomize() with {
        op == OP_WRITE;
        addr[31:16] == 16'h1000;
        burst_len < 8;
      })
        $fatal(1, "Randomization failed");
      txn.display();
    end

    // ---- Turn Off Constraints ----
    $display("\n--- With c_addr_range disabled ---");
    txn.c_addr_range.constraint_mode(0);
    repeat (3) begin
      void'(txn.randomize() with { op == OP_READ; });
      txn.display();
    end
    txn.c_addr_range.constraint_mode(1);

    // ---- Disable Random Field ----
    $display("\n--- addr.rand_mode(0): fixed address ---");
    txn.addr.rand_mode(0);
    txn.addr = 32'hDEAD_BEEF;
    repeat (3) begin
      void'(txn.randomize() with { op == OP_WRITE; });
      txn.display();
    end
    txn.addr.rand_mode(1);

    // ---- randc Demo ----
    $display("\n--- randc id field (cyclic) ---");
    repeat (20) begin
      void'(txn.randomize() with { op == OP_IDLE; });
      $write("id=%0d ", txn.id);
    end
    $display("");

    $display("\n===== All tests passed =====");
  end
endmodule
