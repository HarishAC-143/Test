//-----------------------------------------------------------------------------
// Example: Case Statement Analysis — full_case and parallel_case
//
// SpyGlass Rules Triggered:
//   W_116          - Latch inferred from incomplete case
//   STARC-2.1.4.4  - Missing default in case
//   W_456          - Synthesis directive may cause mismatch
//
// Demonstrates the dangers of 'full_case' and 'parallel_case' synthesis
// pragmas and how SpyGlass detects the resulting mismatches.
//
// IMPORTANT: full_case/parallel_case are widely considered harmful.
// They tell synthesis to assume things that simulation does not,
// creating simulation/synthesis mismatches.
//-----------------------------------------------------------------------------

module case_pragma_bad (
    input  wire [2:0] opcode,
    input  wire [7:0] data_a,
    input  wire [7:0] data_b,
    output reg  [7:0] result
);

    // BUG: 'full_case' tells synthesis this case is complete.
    // But opcodes 3'b100..3'b111 are not covered.
    // - Simulation: result LATCHES for opcodes 4-7
    // - Synthesis:  result is DON'T CARE for opcodes 4-7
    // Result: simulation/synthesis mismatch

    always @(*) begin
        case (opcode) // synthesis full_case
            3'b000: result = data_a;
            3'b001: result = data_b;
            3'b010: result = data_a + data_b;
            3'b011: result = data_a - data_b;
        endcase
    end

endmodule


module case_pragma_bad_parallel (
    input  wire [1:0] sel_a,
    input  wire [1:0] sel_b,
    input  wire [7:0] data_x,
    input  wire [7:0] data_y,
    input  wire [7:0] data_z,
    output reg  [7:0] result
);

    // BUG: 'parallel_case' tells synthesis that cases are mutually exclusive.
    // But (sel_a == 2'b01 && sel_b == 2'b10) matches BOTH arms.
    // - Simulation: first matching branch wins
    // - Synthesis:  both branches are independent — result is OR of both
    // Result: simulation/synthesis mismatch

    always @(*) begin
        result = 8'b0;
        case (1'b1) // synthesis parallel_case
            (sel_a == 2'b01): result = data_x;
            (sel_b == 2'b10): result = data_y;
            (sel_a == 2'b11): result = data_z;
        endcase
    end

endmodule


module case_good (
    input  wire [2:0] opcode,
    input  wire [7:0] data_a,
    input  wire [7:0] data_b,
    output reg  [7:0] result
);

    // FIX: Explicit default handles all uncovered cases
    // No synthesis pragma needed — the code itself is full and unambiguous
    always @(*) begin
        case (opcode)
            3'b000:  result = data_a;
            3'b001:  result = data_b;
            3'b010:  result = data_a + data_b;
            3'b011:  result = data_a - data_b;
            default: result = 8'b0;  // Explicit default, no latch
        endcase
    end

endmodule
