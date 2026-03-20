// ============================================================================
// CPU Definitions Package
// ============================================================================
// Packages centralize type definitions, parameters, and helper functions
// that are shared across multiple modules. Import with:
//   import cpu_pkg::*;
// or selectively:
//   import cpu_pkg::alu_op_t;
// ============================================================================

package cpu_pkg;

    // Global parameters
    parameter int XLEN = 32;
    parameter int REG_ADDR_W = 5;
    parameter int NUM_REGS = 32;

    // ALU operations
    typedef enum logic [3:0] {
        ALU_ADD  = 4'h0,
        ALU_SUB  = 4'h1,
        ALU_AND  = 4'h2,
        ALU_OR   = 4'h3,
        ALU_XOR  = 4'h4,
        ALU_SLL  = 4'h5,
        ALU_SRL  = 4'h6,
        ALU_SRA  = 4'h7,
        ALU_SLT  = 4'h8,
        ALU_SLTU = 4'h9
    } alu_op_t;

    // Instruction fetch packet
    typedef struct packed {
        logic [XLEN-1:0] pc;
        logic [XLEN-1:0] instruction;
        logic             valid;
        logic             predicted_taken;
    } fetch_packet_t;

    // Decoded instruction fields
    typedef struct packed {
        logic [REG_ADDR_W-1:0] rs1;
        logic [REG_ADDR_W-1:0] rs2;
        logic [REG_ADDR_W-1:0] rd;
        alu_op_t               alu_op;
        logic [XLEN-1:0]       immediate;
        logic                  use_imm;
        logic                  reg_write;
        logic                  mem_read;
        logic                  mem_write;
    } decoded_instr_t;

    // Helper functions
    function automatic logic [XLEN-1:0] sign_extend(
        input logic [15:0] imm
    );
        return {{(XLEN-16){imm[15]}}, imm};
    endfunction

    function automatic logic [XLEN-1:0] zero_extend(
        input logic [15:0] imm
    );
        return {{(XLEN-16){1'b0}}, imm};
    endfunction

    function automatic logic is_branch(
        input logic [6:0] opcode
    );
        return (opcode == 7'b1100011);
    endfunction

endpackage
