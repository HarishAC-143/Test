// SystemVerilog interface for the ALU
interface alu_if (input logic clk, input logic rst_n);

  logic [7:0] operand_a;
  logic [7:0] operand_b;
  logic [1:0] operation;
  logic       valid;
  logic [8:0] result;
  logic       result_valid;

  // Clocking block for driver (drives signals on clock edge)
  clocking driver_cb @(posedge clk);
    default input #1 output #1;
    output operand_a;
    output operand_b;
    output operation;
    output valid;
    input  result;
    input  result_valid;
  endclocking

  // Clocking block for monitor (samples signals on clock edge)
  clocking monitor_cb @(posedge clk);
    default input #1 output #1;
    input operand_a;
    input operand_b;
    input operation;
    input valid;
    input result;
    input result_valid;
  endclocking

  // Modport for driver
  modport drv_mp (clocking driver_cb, input clk, input rst_n);

  // Modport for monitor
  modport mon_mp (clocking monitor_cb, input clk, input rst_n);

endinterface
