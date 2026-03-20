interface alu_if (input logic clk, input logic rst_n);

  logic        valid_in;
  logic [2:0]  opcode;
  logic [31:0] operand_a;
  logic [31:0] operand_b;
  logic        valid_out;
  logic [31:0] result;
  logic        zero_flag;
  logic        carry_flag;
  logic        overflow_flag;

  // Driver clocking block
  clocking drv_cb @(posedge clk);
    default input #1 output #1;
    output valid_in, opcode, operand_a, operand_b;
    input  valid_out, result, zero_flag, carry_flag, overflow_flag;
  endclocking

  // Monitor clocking block
  clocking mon_cb @(posedge clk);
    default input #1;
    input valid_in, opcode, operand_a, operand_b;
    input valid_out, result, zero_flag, carry_flag, overflow_flag;
  endclocking

  modport DRV (clocking drv_cb, input clk, rst_n);
  modport MON (clocking mon_cb, input clk, rst_n);

endinterface
