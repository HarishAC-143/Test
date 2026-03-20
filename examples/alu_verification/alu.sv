// DUT: Simple 8-bit ALU with 4 operations
module alu (
  input  logic        clk,
  input  logic        rst_n,
  input  logic [7:0]  operand_a,
  input  logic [7:0]  operand_b,
  input  logic [1:0]  operation,
  input  logic        valid,
  output logic [8:0]  result,
  output logic        result_valid
);

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      result       <= 9'd0;
      result_valid <= 1'b0;
    end else if (valid) begin
      result_valid <= 1'b1;
      case (operation)
        2'b00: result <= {1'b0, operand_a} + {1'b0, operand_b};  // ADD
        2'b01: result <= {1'b0, operand_a} - {1'b0, operand_b};  // SUB
        2'b10: result <= {1'b0, operand_a & operand_b};           // AND
        2'b11: result <= {1'b0, operand_a | operand_b};           // OR
      endcase
    end else begin
      result_valid <= 1'b0;
    end
  end

endmodule
