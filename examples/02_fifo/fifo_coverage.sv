// FIFO Coverage Collector
class fifo_coverage extends uvm_subscriber #(fifo_seq_item);
  `uvm_component_utils(fifo_coverage)

  fifo_seq_item tr;

  covergroup fifo_cg;
    option.per_instance = 1;

    operation_cp: coverpoint {tr.wr_en, tr.rd_en} {
      bins write_only = {2'b10};
      bins read_only  = {2'b01};
      bins idle       = {2'b00};
    }

    data_cp: coverpoint tr.wr_data {
      bins zero     = {0};
      bins low      = {[1:63]};
      bins mid      = {[64:191]};
      bins high     = {[192:254]};
      bins all_ones = {8'hFF};
    }

    full_cp: coverpoint tr.full {
      bins not_full = {0};
      bins is_full  = {1};
    }

    empty_cp: coverpoint tr.empty {
      bins not_empty = {0};
      bins is_empty  = {1};
    }

    // Cross: operation when FIFO is full
    full_x_op: cross full_cp, operation_cp;

    // Cross: operation when FIFO is empty
    empty_x_op: cross empty_cp, operation_cp;
  endgroup

  function new(string name, uvm_component parent);
    super.new(name, parent);
    fifo_cg = new();
  endfunction

  function void write(fifo_seq_item t);
    tr = t;
    fifo_cg.sample();
  endfunction

  function void report_phase(uvm_phase phase);
    `uvm_info("COV", $sformatf("FIFO Functional Coverage: %.2f%%",
              fifo_cg.get_coverage()), UVM_LOW)
  endfunction

endclass
