// UVM Driver and Monitor Example
//
// Demonstrates:
//   - uvm_driver: pulling transactions from sequencer, converting to pin activity
//   - uvm_monitor: passively observing bus signals, constructing transactions
//   - Virtual interface retrieval from uvm_config_db
//   - Analysis port broadcasting
//   - Protocol-specific timing (APB setup/access phases)

`ifndef APB_DRIVER_MONITOR_SV
`define APB_DRIVER_MONITOR_SV

`include "uvm_macros.svh"
import uvm_pkg::*;


// ═══════════════════════════════════════════════════════════════
//  APB Interface
// ═══════════════════════════════════════════════════════════════

interface apb_if(input logic pclk, input logic preset_n);
  logic        psel;
  logic        penable;
  logic        pwrite;
  logic [31:0] paddr;
  logic [31:0] pwdata;
  logic [31:0] prdata;
  logic        pready;
  logic        pslverr;
  logic [3:0]  pstrb;

  clocking driver_cb @(posedge pclk);
    default input #1step output #1;
    output psel, penable, pwrite, paddr, pwdata, pstrb;
    input  prdata, pready, pslverr;
  endclocking

  clocking monitor_cb @(posedge pclk);
    default input #1step;
    input psel, penable, pwrite, paddr, pwdata, prdata, pready, pslverr, pstrb;
  endclocking

  modport driver_mp  (clocking driver_cb, input pclk, preset_n);
  modport monitor_mp (clocking monitor_cb, input pclk, preset_n);
endinterface


// ═══════════════════════════════════════════════════════════════
//  APB Driver
//
//  Pulls apb_transaction items from the sequencer and converts
//  them to APB bus-level signaling.
// ═══════════════════════════════════════════════════════════════

class apb_driver extends uvm_driver #(apb_transaction);
  `uvm_component_utils(apb_driver)

  virtual apb_if vif;
  int unsigned transactions_driven;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    transactions_driven = 0;
  endfunction

  // ── Build Phase: Retrieve virtual interface ──
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual apb_if)::get(this, "", "vif", vif))
      `uvm_fatal("NOVIF", {"Virtual interface not found for ", get_full_name()})
  endfunction

  // ── Run Phase: Main driving loop ──
  virtual task run_phase(uvm_phase phase);
    apb_transaction txn;

    reset_signals();
    @(posedge vif.preset_n);
    `uvm_info(get_type_name(), "Reset de-asserted, starting driver", UVM_LOW)

    forever begin
      seq_item_port.get_next_item(txn);
      `uvm_info(get_type_name(),
        $sformatf("Driving: %s", txn.convert2string()), UVM_HIGH)

      drive_transaction(txn);
      transactions_driven++;

      // Optionally send response for reads
      if (txn.operation == APB_READ) begin
        apb_transaction rsp = apb_transaction::type_id::create("rsp");
        rsp.set_id_info(txn);
        rsp.copy(txn);
        seq_item_port.item_done(rsp);
      end else begin
        seq_item_port.item_done();
      end
    end
  endtask

  // ── Drive a single APB transaction ──
  virtual task drive_transaction(apb_transaction txn);
    // Optional inter-transaction delay
    if (txn.delay > 0)
      repeat (txn.delay) @(posedge vif.pclk);

    // ─ Setup Phase ─
    @(posedge vif.pclk);
    vif.driver_cb.psel    <= 1'b1;
    vif.driver_cb.paddr   <= txn.addr;
    vif.driver_cb.pwrite  <= (txn.operation == APB_WRITE);
    vif.driver_cb.pstrb   <= txn.strobe;
    if (txn.operation == APB_WRITE)
      vif.driver_cb.pwdata <= txn.data;
    vif.driver_cb.penable <= 1'b0;

    txn.start_time = $time;

    // ─ Access Phase ─
    @(posedge vif.pclk);
    vif.driver_cb.penable <= 1'b1;

    // Wait for PREADY
    do @(posedge vif.pclk);
    while (!vif.driver_cb.pready);

    // Capture response
    if (txn.operation == APB_READ)
      txn.read_data = vif.driver_cb.prdata;
    txn.slv_error = vif.driver_cb.pslverr;
    txn.end_time  = $time;

    // ─ Return to Idle ─
    vif.driver_cb.psel    <= 1'b0;
    vif.driver_cb.penable <= 1'b0;
  endtask

  // ── Reset all bus signals to idle ──
  virtual task reset_signals();
    vif.psel    <= 1'b0;
    vif.penable <= 1'b0;
    vif.pwrite  <= 1'b0;
    vif.paddr   <= '0;
    vif.pwdata  <= '0;
    vif.pstrb   <= '0;
  endtask

  // ── Report Phase: Summary ──
  virtual function void report_phase(uvm_phase phase);
    `uvm_info(get_type_name(),
      $sformatf("Driver summary: %0d transactions driven", transactions_driven),
      UVM_LOW)
  endfunction
endclass


// ═══════════════════════════════════════════════════════════════
//  APB Monitor
//
//  Passively observes the APB bus and broadcasts observed
//  transactions through an analysis port.
// ═══════════════════════════════════════════════════════════════

class apb_monitor extends uvm_monitor;
  `uvm_component_utils(apb_monitor)

  virtual apb_if vif;
  uvm_analysis_port #(apb_transaction) ap;

  bit enable_coverage;
  int unsigned transactions_observed;

  // Covergroup for functional coverage
  covergroup apb_cg with function sample(apb_transaction txn);
    option.per_instance = 1;

    cp_operation: coverpoint txn.operation {
      bins read  = {APB_READ};
      bins write = {APB_WRITE};
    }

    cp_addr_range: coverpoint txn.addr[15:12] {
      bins low    = {[0:3]};
      bins mid    = {[4:7]};
      bins high   = {[8:11]};
      bins top    = {[12:15]};
    }

    cp_strobe: coverpoint txn.strobe {
      bins byte0     = {4'b0001};
      bins byte1     = {4'b0010};
      bins byte2     = {4'b0100};
      bins byte3     = {4'b1000};
      bins halfword0 = {4'b0011};
      bins halfword1 = {4'b1100};
      bins word      = {4'b1111};
    }

    cp_error: coverpoint txn.slv_error {
      bins no_error = {0};
      bins error    = {1};
    }

    cross_op_addr: cross cp_operation, cp_addr_range;
    cross_op_err:  cross cp_operation, cp_error;
  endgroup

  function new(string name, uvm_component parent);
    super.new(name, parent);
    apb_cg = new();
    transactions_observed = 0;
  endfunction

  // ── Build Phase ──
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ap = new("ap", this);

    if (!uvm_config_db#(virtual apb_if)::get(this, "", "vif", vif))
      `uvm_fatal("NOVIF", {"Virtual interface not found for ", get_full_name()})

    void'(uvm_config_db#(bit)::get(this, "", "enable_coverage", enable_coverage));
  endfunction

  // ── Run Phase: Observe bus activity ──
  virtual task run_phase(uvm_phase phase);
    @(posedge vif.preset_n);
    `uvm_info(get_type_name(), "Reset de-asserted, starting monitor", UVM_LOW)

    forever begin
      apb_transaction txn;
      collect_transaction(txn);

      if (enable_coverage)
        apb_cg.sample(txn);

      transactions_observed++;
      ap.write(txn);
    end
  endtask

  // ── Collect one complete APB transfer ──
  virtual task collect_transaction(output apb_transaction txn);
    txn = apb_transaction::type_id::create("mon_txn");

    // Wait for Setup Phase: PSEL rises while PENABLE is low
    @(posedge vif.pclk iff (vif.monitor_cb.psel && !vif.monitor_cb.penable));
    txn.addr      = vif.monitor_cb.paddr;
    txn.operation = vif.monitor_cb.pwrite ? APB_WRITE : APB_READ;
    txn.strobe    = vif.monitor_cb.pstrb;
    if (txn.operation == APB_WRITE)
      txn.data = vif.monitor_cb.pwdata;
    txn.start_time = $time;

    // Wait for Access Phase completion: PENABLE and PREADY both high
    @(posedge vif.pclk iff (vif.monitor_cb.penable && vif.monitor_cb.pready));
    if (txn.operation == APB_READ) begin
      txn.data      = vif.monitor_cb.prdata;
      txn.read_data = vif.monitor_cb.prdata;
    end
    txn.slv_error = vif.monitor_cb.pslverr;
    txn.end_time  = $time;

    `uvm_info(get_type_name(),
      $sformatf("Observed: %s (duration: %0t)",
                txn.convert2string(), txn.end_time - txn.start_time),
      UVM_HIGH)
  endtask

  // ── Report Phase ──
  virtual function void report_phase(uvm_phase phase);
    `uvm_info(get_type_name(),
      $sformatf("Monitor summary: %0d transactions observed",
                transactions_observed),
      UVM_LOW)

    if (enable_coverage) begin
      `uvm_info(get_type_name(),
        $sformatf("Functional coverage: %.1f%%",
                  apb_cg.get_inst_coverage()),
        UVM_LOW)
    end
  endfunction
endclass

`endif
