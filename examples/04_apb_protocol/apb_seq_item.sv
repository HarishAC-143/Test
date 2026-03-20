typedef enum bit {
  APB_WRITE = 1'b1,
  APB_READ  = 1'b0
} apb_dir_t;

typedef enum bit [1:0] {
  APB_BYTE = 2'b00,
  APB_HALF = 2'b01,
  APB_WORD = 2'b10
} apb_size_t;

class apb_seq_item extends uvm_sequence_item;
  `uvm_object_utils(apb_seq_item)

  rand apb_dir_t   direction;
  rand bit [7:0]   addr;
  rand bit [31:0]  wdata;
  rand bit [3:0]   strb;
  rand apb_size_t  size;
  rand int         delay;

  // Response (filled by driver/monitor)
  bit [31:0]  rdata;
  bit         slverr;

  // Constraints
  constraint c_addr_aligned {
    (size == APB_WORD) -> (addr[1:0] == 2'b00);
    (size == APB_HALF) -> (addr[0]   == 1'b0);
  }

  constraint c_strb_valid {
    (size == APB_WORD) -> (strb == 4'b1111);
    (size == APB_HALF && addr[1] == 0) -> (strb == 4'b0011);
    (size == APB_HALF && addr[1] == 1) -> (strb == 4'b1100);
    (size == APB_BYTE) -> $onehot(strb);
    (direction == APB_READ) -> (strb == 4'b1111);
  }

  constraint c_addr_range { addr < 8'hFC; }
  constraint c_delay      { delay inside {[0:5]}; }
  constraint c_size_dist  { size dist { APB_WORD := 60, APB_HALF := 20, APB_BYTE := 20 }; }

  function new(string name = "apb_seq_item");
    super.new(name);
  endfunction

  function string convert2string();
    return $sformatf("%s addr=0x%02h %s=0x%08h strb=0x%01h err=%0b",
                     direction == APB_WRITE ? "WR" : "RD",
                     addr,
                     direction == APB_WRITE ? "wdata" : "rdata",
                     direction == APB_WRITE ? wdata : rdata,
                     strb, slverr);
  endfunction

  function void do_copy(uvm_object rhs);
    apb_seq_item rhs_;
    super.do_copy(rhs);
    $cast(rhs_, rhs);
    direction = rhs_.direction;
    addr      = rhs_.addr;
    wdata     = rhs_.wdata;
    strb      = rhs_.strb;
    size      = rhs_.size;
    delay     = rhs_.delay;
    rdata     = rhs_.rdata;
    slverr    = rhs_.slverr;
  endfunction

  function bit do_compare(uvm_object rhs, uvm_comparer comparer);
    apb_seq_item rhs_;
    if (!$cast(rhs_, rhs)) return 0;
    return (super.do_compare(rhs, comparer) &&
            direction == rhs_.direction &&
            addr      == rhs_.addr &&
            wdata     == rhs_.wdata);
  endfunction
endclass
