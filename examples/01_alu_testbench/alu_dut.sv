// Simple 32-bit ALU with synchronous handshake
module alu_dut (
  input  logic        clk,
  input  logic        rst_n,
  input  logic        valid_in,
  input  logic [2:0]  opcode,
  input  logic [31:0] operand_a,
  input  logic [31:0] operand_b,
  output logic        valid_out,
  output logic [31:0] result,
  output logic        zero_flag,
  output logic        carry_flag,
  output logic        overflow_flag
);

  localparam OP_ADD = 3'b000;
  localparam OP_SUB = 3'b001;
  localparam OP_MUL = 3'b010;
  localparam OP_AND = 3'b011;
  localparam OP_OR  = 3'b100;
  localparam OP_XOR = 3'b101;
  localparam OP_SHL = 3'b110;
  localparam OP_SHR = 3'b111;

  logic [32:0] result_wide;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      valid_out     <= 1'b0;
      result        <= 32'h0;
      zero_flag     <= 1'b0;
      carry_flag    <= 1'b0;
      overflow_flag <= 1'b0;
    end else begin
      valid_out <= valid_in;

      if (valid_in) begin
        case (opcode)
          OP_ADD: result_wide = {1'b0, operand_a} + {1'b0, operand_b};
          OP_SUB: result_wide = {1'b0, operand_a} - {1'b0, operand_b};
          OP_MUL: result_wide = {1'b0, operand_a[15:0] * operand_b[15:0]};
          OP_AND: result_wide = {1'b0, operand_a & operand_b};
          OP_OR:  result_wide = {1'b0, operand_a | operand_b};
          OP_XOR: result_wide = {1'b0, operand_a ^ operand_b};
          OP_SHL: result_wide = {1'b0, operand_a << operand_b[4:0]};
          OP_SHR: result_wide = {1'b0, operand_a >> operand_b[4:0]};
          default: result_wide = 33'h0;
        endcase

        result        <= result_wide[31:0];
        zero_flag     <= (result_wide[31:0] == 32'h0);
        carry_flag    <= result_wide[32];
        overflow_flag <= (opcode == OP_ADD) ?
                         (operand_a[31] == operand_b[31]) && (result_wide[31] != operand_a[31]) :
                         (opcode == OP_SUB) ?
                         (operand_a[31] != operand_b[31]) && (result_wide[31] != operand_a[31]) :
                         1'b0;
      end
    end
  end

endmodule
