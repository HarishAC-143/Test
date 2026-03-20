class fifo_coverage extends uvm_subscriber #(fifo_transaction);
  `uvm_component_utils(fifo_coverage)

  fifo_transaction tx;

  covergroup fifo_cg;
    option.per_instance = 1;

    operation_cp: coverpoint tx.op {
      bins write = {FIFO_WRITE};
      bins read  = {FIFO_READ};
    }

    full_cp:  coverpoint tx.full;
    empty_cp: coverpoint tx.empty;
    almost_full_cp:  coverpoint tx.almost_full;
    almost_empty_cp: coverpoint tx.almost_empty;
    overflow_cp:  coverpoint tx.overflow;
    underflow_cp: coverpoint tx.underflow;

    data_cp: coverpoint tx.data {
      bins zero    = {8'h00};
      bins low     = {[8'h01:8'h3F]};
      bins mid     = {[8'h40:8'hBF]};
      bins high    = {[8'hC0:8'hFE]};
      bins max     = {8'hFF};
    }

    op_x_full:  cross operation_cp, full_cp;
    op_x_empty: cross operation_cp, empty_cp;

    // Transitions: check we see transitions between full and not-full
    full_transitions: coverpoint tx.full {
      bins to_full    = (0 => 1);
      bins from_full  = (1 => 0);
    }

    empty_transitions: coverpoint tx.empty {
      bins to_empty   = (0 => 1);
      bins from_empty = (1 => 0);
    }
  endgroup

  function new(string name = "fifo_coverage", uvm_component parent = null);
    super.new(name, parent);
    fifo_cg = new();
  endfunction

  function void write(fifo_transaction t);
    tx = t;
    fifo_cg.sample();
  endfunction

  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info("COV", $sformatf("FIFO Functional Coverage: %.1f%%",
              fifo_cg.get_inst_coverage()), UVM_LOW)
  endfunction
endclass
