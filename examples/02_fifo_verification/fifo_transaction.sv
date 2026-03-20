typedef enum bit {
  FIFO_WRITE = 1'b1,
  FIFO_READ  = 1'b0
} fifo_op_t;

class fifo_transaction extends uvm_sequence_item;
  `uvm_object_utils(fifo_transaction)

  rand fifo_op_t  op;
  rand bit [7:0]  data;
  rand int        delay;

  // Response fields (captured by monitor)
  bit        full;
  bit        empty;
  bit        almost_full;
  bit        almost_empty;
  bit        overflow;
  bit        underflow;
  bit [7:0]  rd_data;

  constraint c_delay { delay inside {[0:3]}; }

  function new(string name = "fifo_transaction");
    super.new(name);
  endfunction

  function string convert2string();
    if (op == FIFO_WRITE)
      return $sformatf("WRITE data=0x%02h full=%0b overflow=%0b", data, full, overflow);
    else
      return $sformatf("READ rd_data=0x%02h empty=%0b underflow=%0b", rd_data, empty, underflow);
  endfunction

  function void do_copy(uvm_object rhs);
    fifo_transaction rhs_;
    super.do_copy(rhs);
    $cast(rhs_, rhs);
    op            = rhs_.op;
    data          = rhs_.data;
    delay         = rhs_.delay;
    full          = rhs_.full;
    empty         = rhs_.empty;
    almost_full   = rhs_.almost_full;
    almost_empty  = rhs_.almost_empty;
    overflow      = rhs_.overflow;
    underflow     = rhs_.underflow;
    rd_data       = rhs_.rd_data;
  endfunction
endclass
