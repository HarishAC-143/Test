//----------------------------------------------------------------------
// Memory Functional Coverage Collector
//
// Subscribes to the monitor analysis port and collects functional
// coverage on address, data, and operation distributions.
//----------------------------------------------------------------------
class mem_coverage extends uvm_subscriber #(mem_seq_item);
  `uvm_component_utils(mem_coverage)

  mem_seq_item txn;

  covergroup mem_cg;
    option.per_instance = 1;
    option.name         = "mem_coverage";

    addr_cp : coverpoint txn.addr {
      bins low_addr  = {[0:3]};
      bins mid_addr  = {[4:11]};
      bins high_addr = {[12:15]};
      bins all_addr[] = {[0:15]};
    }

    wdata_cp : coverpoint txn.wdata {
      bins zero     = {0};
      bins low      = {[1:63]};
      bins mid      = {[64:191]};
      bins high     = {[192:254]};
      bins all_ones = {255};
    }

    op_cp : coverpoint {txn.wr_en, txn.rd_en} {
      bins write = {2'b10};
      bins read  = {2'b01};
      bins idle  = {2'b00};
    }

    addr_x_op : cross addr_cp, op_cp;
  endgroup

  function new(string name = "mem_coverage", uvm_component parent = null);
    super.new(name, parent);
    mem_cg = new();
  endfunction

  function void write(mem_seq_item t);
    txn = t;
    mem_cg.sample();
  endfunction

  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info(get_type_name(),
      $sformatf("Functional Coverage: %.2f%%", mem_cg.get_coverage()),
      UVM_LOW)
  endfunction
endclass
