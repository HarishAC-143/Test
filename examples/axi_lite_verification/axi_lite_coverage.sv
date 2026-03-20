// AXI-Lite Coverage Collector
class axi_lite_coverage extends uvm_subscriber #(axi_lite_txn);

  `uvm_component_utils(axi_lite_coverage)

  axi_lite_txn txn;

  covergroup axi_cg;
    option.per_instance = 1;

    cp_dir: coverpoint txn.dir {
      bins write = {AXI_WRITE};
      bins read  = {AXI_READ};
    }

    cp_addr: coverpoint txn.addr {
      bins reg0 = {32'h00};
      bins reg1 = {32'h04};
      bins reg2 = {32'h08};
      bins reg3 = {32'h0C};
    }

    cp_resp: coverpoint txn.resp {
      bins okay   = {AXI_OKAY};
      bins decerr = {AXI_DECERR};
    }

    cp_data_patterns: coverpoint txn.data {
      bins zero      = {32'h0000_0000};
      bins all_ones  = {32'hFFFF_FFFF};
      bins alt_10    = {32'hAAAA_AAAA};
      bins alt_01    = {32'h5555_5555};
      bins others    = default;
    }

    cp_strb: coverpoint txn.strb iff (txn.dir == AXI_WRITE) {
      bins full_word  = {4'b1111};
      bins byte_0     = {4'b0001};
      bins byte_1     = {4'b0010};
      bins byte_2     = {4'b0100};
      bins byte_3     = {4'b1000};
      bins half_low   = {4'b0011};
      bins half_high  = {4'b1100};
      bins others     = default;
    }

    cx_dir_addr: cross cp_dir, cp_addr;
    cx_dir_resp: cross cp_dir, cp_resp;
  endgroup

  function new(string name, uvm_component parent);
    super.new(name, parent);
    axi_cg = new();
  endfunction

  virtual function void write(axi_lite_txn t);
    txn = t;
    axi_cg.sample();
  endfunction

  virtual function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info("COV", $sformatf("AXI-Lite Coverage: %.2f%%",
              axi_cg.get_coverage()), UVM_NONE)
  endfunction

endclass
