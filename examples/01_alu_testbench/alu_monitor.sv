class alu_monitor extends uvm_monitor;
  `uvm_component_utils(alu_monitor)

  virtual alu_if vif;
  uvm_analysis_port #(alu_transaction) ap;

  function new(string name = "alu_monitor", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ap = new("ap", this);
    if (!uvm_config_db #(virtual alu_if)::get(this, "", "vif", vif))
      `uvm_fatal("NOVIF", "ALU virtual interface not found in config_db")
  endfunction

  task run_phase(uvm_phase phase);
    @(posedge vif.rst_n);

    forever begin
      alu_transaction tx;
      // Capture input
      @(vif.mon_cb iff vif.mon_cb.valid_in);
      tx = alu_transaction::type_id::create("tx");
      tx.opcode    = alu_opcode_t'(vif.mon_cb.opcode);
      tx.operand_a = vif.mon_cb.operand_a;
      tx.operand_b = vif.mon_cb.operand_b;

      // Wait for output (1-cycle latency)
      @(vif.mon_cb iff vif.mon_cb.valid_out);
      tx.result        = vif.mon_cb.result;
      tx.zero_flag     = vif.mon_cb.zero_flag;
      tx.carry_flag    = vif.mon_cb.carry_flag;
      tx.overflow_flag = vif.mon_cb.overflow_flag;

      `uvm_info("MON", tx.convert2string(), UVM_HIGH)
      ap.write(tx);
    end
  endtask
endclass
