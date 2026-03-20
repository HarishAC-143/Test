`include "uvm_macros.svh"

module top;
  import uvm_pkg::*;
  import alu_pkg::*;

  logic clk;
  logic rst_n;

  // Clock generation: 10ns period
  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  // Reset generation
  initial begin
    rst_n = 1'b0;
    repeat(5) @(posedge clk);
    rst_n = 1'b1;
  end

  // DUT interface
  alu_if alu_intf(.clk(clk), .rst_n(rst_n));

  // DUT instantiation
  alu_dut dut (
    .clk          (clk),
    .rst_n        (rst_n),
    .valid_in     (alu_intf.valid_in),
    .opcode       (alu_intf.opcode),
    .operand_a    (alu_intf.operand_a),
    .operand_b    (alu_intf.operand_b),
    .valid_out    (alu_intf.valid_out),
    .result       (alu_intf.result),
    .zero_flag    (alu_intf.zero_flag),
    .carry_flag   (alu_intf.carry_flag),
    .overflow_flag(alu_intf.overflow_flag)
  );

  // Pass virtual interface to UVM
  initial begin
    uvm_config_db #(virtual alu_if)::set(null, "uvm_test_top.env.agent*", "vif", alu_intf);
    run_test();
  end
endmodule
