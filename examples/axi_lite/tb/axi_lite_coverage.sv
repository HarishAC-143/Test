class axi_lite_coverage extends uvm_subscriber #(axi_lite_transaction);
  `uvm_component_utils(axi_lite_coverage)

  axi_lite_transaction tx;

  covergroup axi_cg;
    rw_cp: coverpoint tx.rw {
      bins read  = {0};
      bins write = {1};
    }

    addr_cp: coverpoint tx.addr[5:2] {
      bins regs[] = {[0:15]};
    }

    resp_cp: coverpoint tx.resp {
      bins okay   = {2'b00};
      bins slverr = {2'b10};
      bins decerr = {2'b11};
    }

    wstrb_cp: coverpoint tx.wstrb iff (tx.rw == 1) {
      bins all_bytes   = {4'hF};
      bins byte_0      = {4'h1};
      bins byte_1      = {4'h2};
      bins byte_2      = {4'h4};
      bins byte_3      = {4'h8};
      bins lower_half  = {4'h3};
      bins upper_half  = {4'hC};
      bins others      = default;
    }

    addr_x_rw: cross addr_cp, rw_cp;

    wstrb_x_addr: cross wstrb_cp, addr_cp {
      ignore_bins read_ops = binsof(addr_cp) intersect {[0:15]}
                             with (tx.rw == 0);
    }
  endgroup

  function new(string name, uvm_component parent);
    super.new(name, parent);
    axi_cg = new();
  endfunction

  function void write(axi_lite_transaction t);
    tx = t;
    axi_cg.sample();
  endfunction

  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info("COV", $sformatf("AXI-Lite functional coverage: %.2f%%",
              axi_cg.get_inst_coverage()), UVM_LOW)
  endfunction
endclass
