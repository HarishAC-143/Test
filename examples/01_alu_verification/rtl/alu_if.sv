// ALU Interface — bundles all DUT signals for clean connectivity
interface alu_if (input logic clk, input logic rst_n);

  logic [7:0]  operand_a;
  logic [7:0]  operand_b;
  logic [2:0]  operation;
  logic        valid_in;
  logic [7:0]  result;
  logic        carry_out;
  logic        zero_flag;
  logic        valid_out;

  // Clocking block for the driver (drives inputs on clock edge)
  clocking driver_cb @(posedge clk);
    default input #1step output #0;
    output operand_a;
    output operand_b;
    output operation;
    output valid_in;
    input  result;
    input  carry_out;
    input  zero_flag;
    input  valid_out;
  endclocking

  // Clocking block for the monitor (samples signals on clock edge)
  clocking monitor_cb @(posedge clk);
    default input #1step output #0;
    input operand_a;
    input operand_b;
    input operation;
    input valid_in;
    input result;
    input carry_out;
    input zero_flag;
    input valid_out;
  endclocking

  modport driver_mp  (clocking driver_cb, input clk, input rst_n);
  modport monitor_mp (clocking monitor_cb, input clk, input rst_n);

endinterface
