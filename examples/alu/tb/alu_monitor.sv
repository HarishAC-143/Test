class alu_monitor extends uvm_monitor;
  `uvm_component_utils(alu_monitor)

  virtual alu_if vif;
  uvm_analysis_port #(alu_transaction) ap;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ap = new("ap", this);
    if (!uvm_config_db#(virtual alu_if)::get(this, "", "vif", vif))
      `uvm_fatal("MON", "Failed to get virtual interface from config_db")
  endfunction

  virtual task run_phase(uvm_phase phase);
    alu_transaction tx;
    forever begin
      @(posedge vif.clk);
      if (vif.monitor_cb.valid_in) begin
        tx = alu_transaction::type_id::create("tx");
        tx.operand_a = vif.monitor_cb.operand_a;
        tx.operand_b = vif.monitor_cb.operand_b;
        tx.opcode    = vif.monitor_cb.opcode;

        // Wait one cycle for the result (pipeline latency)
        @(posedge vif.clk);
        tx.result   = vif.monitor_cb.result;
        tx.overflow = vif.monitor_cb.overflow;

        `uvm_info("MON", $sformatf("Observed: %s", tx.convert2string()), UVM_HIGH)
        ap.write(tx);
      end
    end
  endtask
endclass
