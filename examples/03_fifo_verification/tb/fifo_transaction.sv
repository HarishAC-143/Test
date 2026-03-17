// FIFO Transaction
class fifo_transaction extends uvm_sequence_item;
  `uvm_object_utils(fifo_transaction)

  // Stimulus fields
  rand fifo_op_t                       operation;
  rand bit [FIFO_DATA_WIDTH-1:0]       wr_data;

  // Response / status fields
  bit [FIFO_DATA_WIDTH-1:0]  rd_data;
  bit                        full;
  bit                        empty;
  bit [$clog2(FIFO_DEPTH):0] count;
  bit                        write_blocked;   // Set if write attempted when full
  bit                        read_blocked;    // Set if read attempted when empty

  constraint no_idle_c {
    operation != FIFO_IDLE;
  }

  function new(string name = "fifo_transaction");
    super.new(name);
  endfunction

  function void do_copy(uvm_object rhs);
    fifo_transaction rhs_;
    super.do_copy(rhs);
    $cast(rhs_, rhs);
    this.operation     = rhs_.operation;
    this.wr_data       = rhs_.wr_data;
    this.rd_data       = rhs_.rd_data;
    this.full          = rhs_.full;
    this.empty         = rhs_.empty;
    this.count         = rhs_.count;
    this.write_blocked = rhs_.write_blocked;
    this.read_blocked  = rhs_.read_blocked;
  endfunction

  function string convert2string();
    string op_str;
    case (operation)
      FIFO_WRITE: op_str = $sformatf("WRITE data=0x%02h", wr_data);
      FIFO_READ:  op_str = $sformatf("READ  data=0x%02h", rd_data);
      FIFO_BOTH:  op_str = $sformatf("WR+RD wr=0x%02h rd=0x%02h", wr_data, rd_data);
      FIFO_IDLE:  op_str = "IDLE";
    endcase
    return $sformatf("%s | full=%0b empty=%0b count=%0d", op_str, full, empty, count);
  endfunction

endclass
