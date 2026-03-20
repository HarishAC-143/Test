// ============================================================================
// SystemVerilog Data Types — Comprehensive Reference
// ============================================================================
//
// This module demonstrates the major data types used in synthesizable
// SystemVerilog RTL. Instantiate it to see how the tools infer hardware
// from each construct.
// ============================================================================

module data_types_demo (
    input  logic        clk,
    input  logic        rst_n,
    input  logic [7:0]  in_byte,
    input  logic [1:0]  sel,
    output logic [31:0] out_word
);

    // -------------------------------------------------------------------------
    // 1. logic — the universal 4-state RTL type
    // -------------------------------------------------------------------------
    logic              single_bit;
    logic [7:0]        byte_val;
    logic [31:0]       word;
    logic signed [15:0] signed_val;

    // -------------------------------------------------------------------------
    // 2. Enumerated types — ideal for FSM states
    // -------------------------------------------------------------------------
    typedef enum logic [1:0] {
        STATE_IDLE  = 2'b00,
        STATE_RUN   = 2'b01,
        STATE_DONE  = 2'b10,
        STATE_ERROR = 2'b11
    } state_t;

    state_t current_state, next_state;

    // -------------------------------------------------------------------------
    // 3. Packed structs — mapped to a contiguous bit vector
    // -------------------------------------------------------------------------
    typedef struct packed {
        logic [7:0]  opcode;
        logic [7:0]  operand_a;
        logic [7:0]  operand_b;
        logic [7:0]  flags;
    } instruction_t;

    instruction_t instr;

    // -------------------------------------------------------------------------
    // 4. Packed unions — overlay different views of the same bits
    // -------------------------------------------------------------------------
    typedef union packed {
        logic [31:0] raw;
        instruction_t decoded;
        struct packed {
            logic [15:0] upper;
            logic [15:0] lower;
        } halves;
    } word_view_t;

    word_view_t view;

    // -------------------------------------------------------------------------
    // 5. Packed arrays — multi-dimensional bit vectors
    // -------------------------------------------------------------------------
    logic [3:0][7:0] packed_bytes;  // 32-bit packed array: 4 bytes

    // -------------------------------------------------------------------------
    // 6. Constants
    // -------------------------------------------------------------------------
    localparam int TIMEOUT = 1000;
    localparam logic [7:0] MAGIC_BYTE = 8'hA5;

    // -------------------------------------------------------------------------
    // Demo logic: register the input and use various types
    // -------------------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= STATE_IDLE;
            byte_val      <= '0;
            view.raw      <= '0;
        end else begin
            current_state <= next_state;
            byte_val      <= in_byte;

            unique case (sel)
                2'b00: view.raw <= {4{in_byte}};
                2'b01: view.halves.lower <= {2{in_byte}};
                2'b10: view.decoded.opcode <= in_byte;
                2'b11: view.raw <= {MAGIC_BYTE, in_byte, in_byte, MAGIC_BYTE};
            endcase
        end
    end

    always_comb begin
        next_state = current_state;
        unique case (current_state)
            STATE_IDLE:  if (in_byte != '0) next_state = STATE_RUN;
            STATE_RUN:   if (in_byte == MAGIC_BYTE) next_state = STATE_DONE;
            STATE_DONE:  next_state = STATE_IDLE;
            STATE_ERROR: next_state = STATE_IDLE;
            default:     next_state = STATE_IDLE;
        endcase
    end

    assign out_word = view.raw;

endmodule
