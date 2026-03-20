// APB Coverage Collector — measures functional coverage of APB transactions
class apb_coverage extends uvm_subscriber #(apb_seq_item);
  `uvm_component_utils(apb_coverage)

  apb_seq_item tr;

  covergroup apb_cg;
    option.per_instance = 1;
    option.name = "apb_coverage";

    addr_cp: coverpoint tr.addr[9:2] {
      bins low_quarter  = {[0:63]};
      bins mid_low      = {[64:127]};
      bins mid_high     = {[128:191]};
      bins high_quarter = {[192:255]};
    }

    write_cp: coverpoint tr.write {
      bins read  = {0};
      bins write = {1};
    }

    data_cp: coverpoint tr.data {
      bins zero      = {32'h0};
      bins low       = {[32'h1 : 32'hFF]};
      bins medium    = {[32'h100 : 32'hFFFF]};
      bins high      = {[32'h1_0000 : 32'hFFFF_FFFE]};
      bins all_ones  = {32'hFFFF_FFFF};
    }

    // Cross coverage: address range vs read/write
    addr_x_write: cross addr_cp, write_cp;

    // Cross coverage: data range vs read/write
    data_x_write: cross data_cp, write_cp;
  endgroup

  function new(string name, uvm_component parent);
    super.new(name, parent);
    apb_cg = new();
  endfunction

  function void write(apb_seq_item t);
    tr = t;
    apb_cg.sample();
  endfunction

  function void report_phase(uvm_phase phase);
    `uvm_info("COV", $sformatf("APB Functional Coverage: %.2f%%",
              apb_cg.get_coverage()), UVM_LOW)
  endfunction

endclass
