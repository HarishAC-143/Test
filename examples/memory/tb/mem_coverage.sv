class mem_coverage extends uvm_subscriber #(mem_transaction);
  `uvm_component_utils(mem_coverage)

  mem_transaction tx;

  covergroup mem_cg;
    operation_cp: coverpoint {tx.we, tx.re} {
      bins write = {2'b10};
      bins read  = {2'b01};
    }

    addr_cp: coverpoint tx.addr {
      bins low   = {[0:63]};
      bins mid   = {[64:191]};
      bins high  = {[192:255]};
    }

    byte_en_cp: coverpoint tx.be {
      bins all_bytes   = {4'hF};
      bins byte_0_only = {4'h1};
      bins byte_1_only = {4'h2};
      bins byte_2_only = {4'h4};
      bins byte_3_only = {4'h8};
      bins lower_half  = {4'h3};
      bins upper_half  = {4'hC};
      bins others      = default;
    }

    addr_x_op: cross addr_cp, operation_cp;

    be_x_write: cross byte_en_cp, operation_cp {
      ignore_bins read_be = binsof(operation_cp.read);
    }
  endgroup

  function new(string name, uvm_component parent);
    super.new(name, parent);
    mem_cg = new();
  endfunction

  function void write(mem_transaction t);
    tx = t;
    mem_cg.sample();
  endfunction

  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info("COV", $sformatf("Memory functional coverage: %.2f%%",
              mem_cg.get_inst_coverage()), UVM_LOW)
  endfunction
endclass
