// Simple 32-bit ALU DUT
module alu_dut (
  input  logic        clk,
  input  logic        rst_n,
  input  logic [31:0] operand_a,
  input  logic [31:0] operand_b,
  input  logic [3:0]  opcode,
  input  logic        start,
  output logic [31:0] result,
  output logic        zero_flag,
  output logic        carry_flag,
  output logic        overflow_flag,
  output logic        done
);

  // Opcode definitions
  localparam OP_ADD  = 4'h0;
  localparam OP_SUB  = 4'h1;
  localparam OP_AND  = 4'h2;
  localparam OP_OR   = 4'h3;
  localparam OP_XOR  = 4'h4;
  localparam OP_NOT  = 4'h5;
  localparam OP_SLL  = 4'h6;  // Shift left logical
  localparam OP_SRL  = 4'h7;  // Shift right logical
  localparam OP_SRA  = 4'h8;  // Shift right arithmetic
  localparam OP_MUL  = 4'h9;  // Multiply (lower 32 bits)
  localparam OP_INC  = 4'hA;  // Increment A
  localparam OP_DEC  = 4'hB;  // Decrement A
  localparam OP_PASS = 4'hF;  // Pass-through A

  logic [32:0] extended_result;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      result        <= 0;
      zero_flag     <= 0;
      carry_flag    <= 0;
      overflow_flag <= 0;
      done          <= 0;
    end else if (start) begin
      done <= 1;
      case (opcode)
        OP_ADD: begin
          extended_result = {1'b0, operand_a} + {1'b0, operand_b};
          result     <= extended_result[31:0];
          carry_flag <= extended_result[32];
          overflow_flag <= (operand_a[31] == operand_b[31]) &&
                           (extended_result[31] != operand_a[31]);
        end
        OP_SUB: begin
          extended_result = {1'b0, operand_a} - {1'b0, operand_b};
          result     <= extended_result[31:0];
          carry_flag <= extended_result[32];
          overflow_flag <= (operand_a[31] != operand_b[31]) &&
                           (extended_result[31] != operand_a[31]);
        end
        OP_AND: begin
          result        <= operand_a & operand_b;
          carry_flag    <= 0;
          overflow_flag <= 0;
        end
        OP_OR: begin
          result        <= operand_a | operand_b;
          carry_flag    <= 0;
          overflow_flag <= 0;
        end
        OP_XOR: begin
          result        <= operand_a ^ operand_b;
          carry_flag    <= 0;
          overflow_flag <= 0;
        end
        OP_NOT: begin
          result        <= ~operand_a;
          carry_flag    <= 0;
          overflow_flag <= 0;
        end
        OP_SLL: begin
          result        <= operand_a << operand_b[4:0];
          carry_flag    <= 0;
          overflow_flag <= 0;
        end
        OP_SRL: begin
          result        <= operand_a >> operand_b[4:0];
          carry_flag    <= 0;
          overflow_flag <= 0;
        end
        OP_SRA: begin
          result        <= $signed(operand_a) >>> operand_b[4:0];
          carry_flag    <= 0;
          overflow_flag <= 0;
        end
        OP_MUL: begin
          result        <= operand_a[15:0] * operand_b[15:0];
          carry_flag    <= 0;
          overflow_flag <= 0;
        end
        OP_INC: begin
          extended_result = {1'b0, operand_a} + 1;
          result     <= extended_result[31:0];
          carry_flag <= extended_result[32];
          overflow_flag <= (operand_a == 32'h7FFF_FFFF);
        end
        OP_DEC: begin
          extended_result = {1'b0, operand_a} - 1;
          result     <= extended_result[31:0];
          carry_flag <= extended_result[32];
          overflow_flag <= (operand_a == 32'h8000_0000);
        end
        OP_PASS: begin
          result        <= operand_a;
          carry_flag    <= 0;
          overflow_flag <= 0;
        end
        default: begin
          result        <= 0;
          carry_flag    <= 0;
          overflow_flag <= 0;
        end
      endcase

      // Zero flag is common to all operations
      zero_flag <= (result == 0);
    end else begin
      done <= 0;
    end
  end

endmodule
