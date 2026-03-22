// =============================================================================
// Example 04: Parameterized Classes and Advanced OOP
// Covers: type parameters, value parameters, generic containers,
//         semaphores, mailboxes, and event synchronization
// =============================================================================

// --- Generic FIFO ---
class Fifo #(type T = int, int DEPTH = 8);
  local T    storage[$];
  local int  max_depth;
  local int  push_count;
  local int  pop_count;

  function new();
    max_depth  = DEPTH;
    push_count = 0;
    pop_count  = 0;
  endfunction

  function bit push(T item);
    if (storage.size() >= max_depth) begin
      $warning("FIFO full — push rejected");
      return 0;
    end
    storage.push_back(item);
    push_count++;
    return 1;
  endfunction

  function bit pop(output T item);
    if (storage.size() == 0) begin
      $warning("FIFO empty — pop rejected");
      return 0;
    end
    item = storage.pop_front();
    pop_count++;
    return 1;
  endfunction

  function T peek();
    if (storage.size() == 0)
      $fatal(1, "FIFO empty — cannot peek");
    return storage[0];
  endfunction

  function int size();       return storage.size();  endfunction
  function bit is_empty();   return storage.size() == 0; endfunction
  function bit is_full();    return storage.size() >= max_depth; endfunction
  function int get_pushes(); return push_count; endfunction
  function int get_pops();   return pop_count;  endfunction

  function void display(string name = "FIFO");
    $display("%s: size=%0d/%0d pushes=%0d pops=%0d",
             name, storage.size(), max_depth, push_count, pop_count);
  endfunction
endclass


// --- Generic Associative Map ---
class AssocMap #(type KEY_T = string, type VAL_T = int);
  local VAL_T storage[KEY_T];

  function void put(KEY_T key, VAL_T value);
    storage[key] = value;
  endfunction

  function bit get(KEY_T key, output VAL_T value);
    if (storage.exists(key)) begin
      value = storage[key];
      return 1;
    end
    return 0;
  endfunction

  function bit exists(KEY_T key);
    return storage.exists(key);
  endfunction

  function void remove(KEY_T key);
    if (storage.exists(key))
      storage.delete(key);
  endfunction

  function int size();
    return storage.size();
  endfunction

  function void display(string name = "Map");
    $display("%s: %0d entries", name, storage.size());
    foreach (storage[k])
      $display("  [%p] = %p", k, storage[k]);
  endfunction
endclass


// --- Producer / Consumer with Mailbox ---
class Producer #(type T = int);
  mailbox #(T) mbx;
  string       name;
  int          count;

  function new(string name, mailbox #(T) mbx, int count = 5);
    this.name  = name;
    this.mbx   = mbx;
    this.count = count;
  endfunction

  task run();
    for (int i = 0; i < count; i++) begin
      T item = T'(i * 10 + $urandom_range(0, 9));
      mbx.put(item);
      $display("[%0t] %s produced: %p", $time, name, item);
      #($urandom_range(5, 15));
    end
    $display("[%0t] %s done producing", $time, name);
  endtask
endclass


class Consumer #(type T = int);
  mailbox #(T) mbx;
  string       name;
  T            received[$];

  function new(string name, mailbox #(T) mbx);
    this.name = name;
    this.mbx  = mbx;
  endfunction

  task run(int num_items);
    T item;
    repeat (num_items) begin
      mbx.get(item);
      received.push_back(item);
      $display("[%0t] %s consumed: %p", $time, name, item);
      #($urandom_range(3, 10));
    end
    $display("[%0t] %s done consuming %0d items", $time, name, received.size());
  endtask
endclass


// --- Shared resource with semaphore ---
class SharedCounter;
  local semaphore lock;
  local int value;
  string name;

  function new(string name = "counter");
    lock = new(1);
    value = 0;
    this.name = name;
  endfunction

  task increment(string who, int amount = 1);
    lock.get(1);
    $display("[%0t] %s acquired lock on %s, incrementing by %0d", $time, who, name, amount);
    #10;
    value += amount;
    $display("[%0t] %s releasing lock, %s = %0d", $time, who, name, value);
    lock.put(1);
  endtask

  function int get_value();
    return value;
  endfunction
endclass


module tb_parameterized;
  initial begin
    $display("\n=== Part 1: Parameterized FIFO ===");
    begin
      Fifo #(int, 4)        int_fifo  = new();
      Fifo #(string, 8)     str_fifo  = new();
      Fifo #(bit [7:0], 16) byte_fifo = new();

      int val;

      int_fifo.push(10);
      int_fifo.push(20);
      int_fifo.push(30);
      int_fifo.push(40);
      int_fifo.push(50);  // Rejected — full
      int_fifo.display("IntFIFO");

      while (!int_fifo.is_empty()) begin
        void'(int_fifo.pop(val));
        $display("  Popped: %0d", val);
      end

      str_fifo.push("hello");
      str_fifo.push("world");
      str_fifo.push("from");
      str_fifo.push("parameterized");
      str_fifo.push("class");
      str_fifo.display("StringFIFO");

      for (int i = 0; i < 16; i++)
        byte_fifo.push(i * 11);
      byte_fifo.display("ByteFIFO");
    end

    $display("\n=== Part 2: Generic Associative Map ===");
    begin
      AssocMap #(string, int)    scores = new();
      AssocMap #(int, string)    names  = new();

      int val;
      string sval;

      scores.put("Alice", 95);
      scores.put("Bob", 87);
      scores.put("Charlie", 92);

      if (scores.get("Bob", val))
        $display("Bob's score: %0d", val);

      names.put(1, "Module_A");
      names.put(2, "Module_B");

      if (names.get(2, sval))
        $display("ID 2 = %s", sval);

      scores.display("Scores");
      names.display("Names");
    end
  end

  initial begin
    $display("\n=== Part 3: Mailbox Producer/Consumer ===");
    begin
      mailbox #(int) mbx = new(4);
      Producer #(int) prod = new("Prod", mbx, 6);
      Consumer #(int) cons = new("Cons", mbx);

      fork
        prod.run();
        cons.run(6);
      join

      $display("Consumer received %0d items", cons.received.size());
    end
  end

  initial begin
    #500;
    $display("\n=== Part 4: Semaphore-Protected Shared Resource ===");
    begin
      SharedCounter ctr = new("shared_ctr");

      fork
        repeat (3) ctr.increment("Thread_A", 1);
        repeat (3) ctr.increment("Thread_B", 2);
        repeat (3) ctr.increment("Thread_C", 3);
      join

      $display("Final counter value: %0d (expected 18)", ctr.get_value());
    end
  end

  initial begin
    #2000;
    $finish;
  end
endmodule
