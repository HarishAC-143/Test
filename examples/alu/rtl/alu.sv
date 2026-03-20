// Simple 8-bit ALU with 4 operations
module alu (
  input  logic        clk,
  input  logic        rst_n,
  input  logic [7:0]  operand_a,
  input  logic [7:0]  operand_b,
  input  logic [1:0]  opcode,
  input  logic        valid_in,
  output logic [15:0] result,
  output logic        valid_out,
  output logic        overflow
);

  localparam OP_ADD = 2'b00;
  localparam OP_SUB = 2'b01;
  localparam OP_MUL = 2'b10;
  localparam OP_AND = 2'b11;

  logic [15:0] result_next;
  logic        overflow_next;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      result    <= '0;
      valid_out <= 1'b0;
      overflow  <= 1'b0;
    end else begin
      valid_out <= valid_in;
      if (valid_in) begin
        result   <= result_next;
        overflow <= overflow_next;
      end else begin
        overflow <= 1'b0;
      end
    end
  end

  always_comb begin
    result_next   = '0;
    overflow_next = 1'b0;

    case (opcode)
      OP_ADD: begin
        {overflow_next, result_next[7:0]} = operand_a + operand_b;
        result_next[15:8] = '0;
      end
      OP_SUB: begin
        result_next[7:0]  = operand_a - operand_b;
        result_next[15:8] = '0;
        overflow_next     = (operand_a < operand_b);
      end
      OP_MUL: begin
        result_next = operand_a * operand_b;
      end
      OP_AND: begin
        result_next[7:0]  = operand_a & operand_b;
        result_next[15:8] = '0;
      end
    endcase
  end

endmodule
