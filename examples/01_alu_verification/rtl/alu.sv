// Simple 8-bit ALU — Design Under Test
module alu (
  input  logic        clk,
  input  logic        rst_n,
  input  logic [7:0]  operand_a,
  input  logic [7:0]  operand_b,
  input  logic [2:0]  operation,
  input  logic        valid_in,
  output logic [7:0]  result,
  output logic        carry_out,
  output logic        zero_flag,
  output logic        valid_out
);

  localparam ADD = 3'b000;
  localparam SUB = 3'b001;
  localparam AND_OP = 3'b010;
  localparam OR_OP  = 3'b011;
  localparam XOR_OP = 3'b100;

  logic [8:0] result_wide;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      result    <= 8'h00;
      carry_out <= 1'b0;
      zero_flag <= 1'b0;
      valid_out <= 1'b0;
    end else if (valid_in) begin
      valid_out <= 1'b1;
      case (operation)
        ADD:     result_wide = operand_a + operand_b;
        SUB:     result_wide = operand_a - operand_b;
        AND_OP:  result_wide = {1'b0, operand_a & operand_b};
        OR_OP:   result_wide = {1'b0, operand_a | operand_b};
        XOR_OP:  result_wide = {1'b0, operand_a ^ operand_b};
        default: result_wide = 9'h000;
      endcase
      result    <= result_wide[7:0];
      carry_out <= result_wide[8];
      zero_flag <= (result_wide[7:0] == 8'h00);
    end else begin
      valid_out <= 1'b0;
    end
  end

endmodule
