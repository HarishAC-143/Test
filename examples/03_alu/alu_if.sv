// ALU Interface
interface alu_if(input logic clk, input logic rst_n);

  logic [31:0] operand_a;
  logic [31:0] operand_b;
  logic [3:0]  opcode;
  logic        start;
  logic [31:0] result;
  logic        zero_flag;
  logic        carry_flag;
  logic        overflow_flag;
  logic        done;

  clocking driver_cb @(posedge clk);
    default input #1 output #1;
    output operand_a, operand_b, opcode, start;
    input  result, zero_flag, carry_flag, overflow_flag, done;
  endclocking

  clocking monitor_cb @(posedge clk);
    default input #1 output #1;
    input operand_a, operand_b, opcode, start;
    input result, zero_flag, carry_flag, overflow_flag, done;
  endclocking

  modport driver  (clocking driver_cb, input clk, rst_n);
  modport monitor (clocking monitor_cb, input clk, rst_n);

endinterface
