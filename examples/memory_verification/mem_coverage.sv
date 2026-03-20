// Memory Coverage Collector — tracks functional coverage
class mem_coverage extends uvm_subscriber #(mem_txn);

  `uvm_component_utils(mem_coverage)

  mem_txn txn;

  covergroup mem_cg;
    option.per_instance = 1;

    cp_op: coverpoint txn.op {
      bins write = {MEM_WRITE};
      bins read  = {MEM_READ};
    }

    cp_addr: coverpoint txn.addr {
      bins first  = {8'h00};
      bins low    = {[8'h01:8'h3F]};
      bins mid    = {[8'h40:8'hBF]};
      bins high   = {[8'hC0:8'hFE]};
      bins last   = {8'hFF};
    }

    cp_wdata: coverpoint txn.wdata iff (txn.op == MEM_WRITE) {
      bins zero      = {8'h00};
      bins all_ones  = {8'hFF};
      bins walking_1 = {8'h01, 8'h02, 8'h04, 8'h08, 8'h10, 8'h20, 8'h40, 8'h80};
      bins others    = default;
    }

    cx_op_addr: cross cp_op, cp_addr;
  endgroup

  function new(string name, uvm_component parent);
    super.new(name, parent);
    mem_cg = new();
  endfunction

  virtual function void write(mem_txn t);
    txn = t;
    mem_cg.sample();
  endfunction

  virtual function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info("COV", $sformatf("Memory Coverage: %.2f%%", mem_cg.get_coverage()), UVM_NONE)
  endfunction

endclass
