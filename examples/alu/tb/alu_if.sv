// ALU interface -- bundles all DUT signals
interface alu_if(input logic clk);
  logic        rst_n;
  logic [7:0]  operand_a;
  logic [7:0]  operand_b;
  logic [1:0]  opcode;
  logic        valid_in;
  logic [15:0] result;
  logic        valid_out;
  logic        overflow;

  // Clocking block for the driver (active signals)
  clocking driver_cb @(posedge clk);
    default input #1 output #1;
    output operand_a;
    output operand_b;
    output opcode;
    output valid_in;
    output rst_n;
    input  result;
    input  valid_out;
    input  overflow;
  endclocking

  // Clocking block for the monitor (passive observation)
  clocking monitor_cb @(posedge clk);
    default input #1;
    input operand_a;
    input operand_b;
    input opcode;
    input valid_in;
    input rst_n;
    input result;
    input valid_out;
    input overflow;
  endclocking

  modport driver  (clocking driver_cb);
  modport monitor (clocking monitor_cb);
endinterface
