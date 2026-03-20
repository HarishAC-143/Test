class apb_coverage extends uvm_subscriber #(apb_seq_item);
  `uvm_component_utils(apb_coverage)

  apb_seq_item tx;

  covergroup apb_cg;
    option.per_instance = 1;

    direction_cp: coverpoint tx.direction {
      bins write = {APB_WRITE};
      bins read  = {APB_READ};
    }

    addr_cp: coverpoint tx.addr {
      bins addr_0     = {8'h00};
      bins addr_low   = {[8'h04:8'h3F]};
      bins addr_mid   = {[8'h40:8'h7F]};
      bins addr_high  = {[8'h80:8'hBF]};
      bins addr_top   = {[8'hC0:8'hFF]};
    }

    strb_cp: coverpoint tx.strb {
      bins all_bytes  = {4'b1111};
      bins low_half   = {4'b0011};
      bins high_half  = {4'b1100};
      bins byte_0     = {4'b0001};
      bins byte_1     = {4'b0010};
      bins byte_2     = {4'b0100};
      bins byte_3     = {4'b1000};
    }

    slverr_cp: coverpoint tx.slverr;

    wdata_cp: coverpoint tx.wdata {
      bins zero     = {32'h0};
      bins low      = {[32'h1:32'hFF]};
      bins mid      = {[32'h100:32'hFFFF]};
      bins high     = {[32'h1_0000:32'hFFFF_FFFE]};
      bins all_ones = {32'hFFFF_FFFF};
    }

    dir_x_addr:  cross direction_cp, addr_cp;
    dir_x_strb:  cross direction_cp, strb_cp {
      ignore_bins read_strb = binsof(direction_cp.read);
    }
    dir_x_err:   cross direction_cp, slverr_cp;

    // Back-to-back transitions
    dir_transition: coverpoint tx.direction {
      bins wr_wr = (APB_WRITE => APB_WRITE);
      bins wr_rd = (APB_WRITE => APB_READ);
      bins rd_wr = (APB_READ  => APB_WRITE);
      bins rd_rd = (APB_READ  => APB_READ);
    }
  endgroup

  function new(string name = "apb_coverage", uvm_component parent = null);
    super.new(name, parent);
    apb_cg = new();
  endfunction

  function void write(apb_seq_item t);
    tx = t;
    apb_cg.sample();
  endfunction

  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info("COV", $sformatf("APB Functional Coverage: %.1f%%",
              apb_cg.get_inst_coverage()), UVM_LOW)
  endfunction
endclass
