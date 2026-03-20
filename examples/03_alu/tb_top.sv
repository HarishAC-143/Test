// Top-level testbench for ALU verification
`include "uvm_macros.svh"

module tb_top;

  import uvm_pkg::*;
  import alu_pkg::*;

  logic clk;
  logic rst_n;

  // Clock: 100 MHz
  initial begin
    clk = 0;
    forever #5ns clk = ~clk;
  end

  // Reset
  initial begin
    rst_n = 0;
    #50ns;
    rst_n = 1;
  end

  // Interface
  alu_if alu_vif(.clk(clk), .rst_n(rst_n));

  // DUT
  alu_dut dut (
    .clk           (clk),
    .rst_n         (rst_n),
    .operand_a     (alu_vif.operand_a),
    .operand_b     (alu_vif.operand_b),
    .opcode        (alu_vif.opcode),
    .start         (alu_vif.start),
    .result        (alu_vif.result),
    .zero_flag     (alu_vif.zero_flag),
    .carry_flag    (alu_vif.carry_flag),
    .overflow_flag (alu_vif.overflow_flag),
    .done          (alu_vif.done)
  );

  initial begin
    uvm_config_db#(virtual alu_if)::set(null, "uvm_test_top.env.agent.*", "vif", alu_vif);
  end

  initial begin
    run_test();
  end

  initial begin
    #10ms;
    `uvm_fatal("TIMEOUT", "Simulation timed out")
  end

  initial begin
    $dumpfile("alu.vcd");
    $dumpvars(0, tb_top);
  end

endmodule
