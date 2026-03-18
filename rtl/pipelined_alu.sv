// =============================================================================
// Multi-Stage Pipelined ALU with Forwarding
// Demonstrates: Pipeline stages, hazard detection, data forwarding, structs
// =============================================================================

package alu_pkg;
    typedef enum logic [3:0] {
        ALU_ADD  = 4'b0000,
        ALU_SUB  = 4'b0001,
        ALU_AND  = 4'b0010,
        ALU_OR   = 4'b0011,
        ALU_XOR  = 4'b0100,
        ALU_SLL  = 4'b0101,
        ALU_SRL  = 4'b0110,
        ALU_SRA  = 4'b0111,
        ALU_SLT  = 4'b1000,
        ALU_SLTU = 4'b1001,
        ALU_MUL  = 4'b1010,
        ALU_MULH = 4'b1011
    } alu_op_e;

    typedef struct packed {
        logic        valid;
        alu_op_e     op;
        logic [31:0] operand_a;
        logic [31:0] operand_b;
        logic [4:0]  rd_addr;
    } pipe_stage_t;
endpackage

module pipelined_alu
    import alu_pkg::*;
(
    input  logic        clk,
    input  logic        rst_n,
    input  logic        flush,
    input  logic        stall,

    // Input operands
    input  logic        valid_in,
    input  alu_op_e     op_in,
    input  logic [31:0] operand_a,
    input  logic [31:0] operand_b,
    input  logic [4:0]  rd_addr_in,

    // Forwarding inputs
    input  logic        fwd_valid,
    input  logic [4:0]  fwd_addr,
    input  logic [31:0] fwd_data,

    // Result output
    output logic        valid_out,
    output logic [31:0] result,
    output logic [4:0]  rd_addr_out,
    output logic        overflow
);

    // Pipeline registers
    pipe_stage_t stage1, stage2;

    logic [31:0] alu_result_s1;
    logic [63:0] mul_result;
    logic [31:0] final_result;
    logic        overflow_s1;

    // Stage 1: Decode & Execute (combinational ALU operations)
    always_comb begin
        alu_result_s1 = '0;
        overflow_s1   = 1'b0;
        mul_result    = '0;

        unique case (stage1.op)
            ALU_ADD: begin
                {overflow_s1, alu_result_s1} = {1'b0, stage1.operand_a} +
                                                {1'b0, stage1.operand_b};
            end
            ALU_SUB: begin
                {overflow_s1, alu_result_s1} = {1'b0, stage1.operand_a} -
                                                {1'b0, stage1.operand_b};
            end
            ALU_AND:  alu_result_s1 = stage1.operand_a & stage1.operand_b;
            ALU_OR:   alu_result_s1 = stage1.operand_a | stage1.operand_b;
            ALU_XOR:  alu_result_s1 = stage1.operand_a ^ stage1.operand_b;
            ALU_SLL:  alu_result_s1 = stage1.operand_a << stage1.operand_b[4:0];
            ALU_SRL:  alu_result_s1 = stage1.operand_a >> stage1.operand_b[4:0];
            ALU_SRA:  alu_result_s1 = $signed(stage1.operand_a) >>> stage1.operand_b[4:0];
            ALU_SLT:  alu_result_s1 = {31'b0, $signed(stage1.operand_a) < $signed(stage1.operand_b)};
            ALU_SLTU: alu_result_s1 = {31'b0, stage1.operand_a < stage1.operand_b};
            ALU_MUL: begin
                mul_result    = $signed(stage1.operand_a) * $signed(stage1.operand_b);
                alu_result_s1 = mul_result[31:0];
            end
            ALU_MULH: begin
                mul_result    = $signed(stage1.operand_a) * $signed(stage1.operand_b);
                alu_result_s1 = mul_result[63:32];
            end
            default: alu_result_s1 = '0;
        endcase
    end

    // Pipeline Stage 1: Input registration with forwarding
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n || flush) begin
            stage1 <= '0;
        end else if (!stall) begin
            stage1.valid     <= valid_in;
            stage1.op        <= op_in;
            stage1.rd_addr   <= rd_addr_in;

            // Data forwarding: substitute operand if forwarding match
            stage1.operand_a <= (fwd_valid && fwd_addr == rd_addr_in) ?
                                 fwd_data : operand_a;
            stage1.operand_b <= operand_b;
        end
    end

    // Pipeline Stage 2: Result registration
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n || flush) begin
            stage2      <= '0;
            valid_out   <= 1'b0;
            result      <= '0;
            rd_addr_out <= '0;
            overflow    <= 1'b0;
        end else if (!stall) begin
            valid_out   <= stage1.valid;
            result      <= alu_result_s1;
            rd_addr_out <= stage1.rd_addr;
            overflow    <= overflow_s1 && stage1.valid;
        end
    end

endmodule
