// ALU Operation Package
// Defines opcodes shared between ALU, decoder, and testbench

package alu_pkg;

    typedef enum logic [3:0] {
        ALU_ADD  = 4'b0000,
        ALU_SUB  = 4'b0001,
        ALU_AND  = 4'b0010,
        ALU_OR   = 4'b0011,
        ALU_XOR  = 4'b0100,
        ALU_SLL  = 4'b0101,  // Shift left logical
        ALU_SRL  = 4'b0110,  // Shift right logical
        ALU_SRA  = 4'b0111,  // Shift right arithmetic
        ALU_SLT  = 4'b1000,  // Set less than (signed)
        ALU_SLTU = 4'b1001,  // Set less than (unsigned)
        ALU_NOR  = 4'b1010,
        ALU_XNOR = 4'b1011,
        ALU_PASS = 4'b1100   // Pass operand_a through
    } alu_op_t;

    typedef struct packed {
        logic zero;
        logic negative;
        logic overflow;
        logic carry;
    } alu_flags_t;

endpackage
