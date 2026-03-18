// =============================================================================
// SpyGlass Lint Example: Inferred Latch (W15)
// =============================================================================
//
// SpyGlass Rule: W15
// Severity:      Warning
// Category:      Synthesis
//
// This module demonstrates how an incomplete if/case statement in a
// combinational always block causes SpyGlass to report W15, indicating
// that synthesis will infer a latch to hold the output value when none
// of the explicit conditions are met.
//
// Run with: current_goal lint/lint_rtl
// =============================================================================

module priority_encoder_buggy (
    input  [3:0] req,
    output reg [1:0] grant
);

    // W15 VIOLATION: No 'else' or 'default' branch.
    // When req[3:1] are all zero, grant retains its previous value,
    // forcing synthesis to infer a latch.
    always @(*) begin
        if (req[3])
            grant = 2'b11;
        else if (req[2])
            grant = 2'b10;
        else if (req[1])
            grant = 2'b01;
        // Missing: else grant = 2'b00;
    end

endmodule


// Another common pattern: incomplete case statement
module alu_buggy (
    input  [1:0] op,
    input  [7:0] a, b,
    output reg [7:0] result
);

    // W15 VIOLATION: case does not cover all values of 'op'
    // and has no 'default' branch.
    always @(*) begin
        case (op)
            2'b00: result = a + b;
            2'b01: result = a - b;
            2'b10: result = a & b;
            // Missing: 2'b11 and/or default
        endcase
    end

endmodule


// Yet another pattern: conditional assignment where one branch omits
// an output in a multi-output block
module decoder_buggy (
    input  [1:0] sel,
    output reg       valid,
    output reg [3:0] decoded
);

    // W15 VIOLATION: 'valid' is not assigned in the default branch
    always @(*) begin
        decoded = 4'b0000;
        case (sel)
            2'b00: begin decoded = 4'b0001; valid = 1'b1; end
            2'b01: begin decoded = 4'b0010; valid = 1'b1; end
            2'b10: begin decoded = 4'b0100; valid = 1'b1; end
            default: begin
                decoded = 4'b0000;
                // 'valid' not assigned here → latch inferred for 'valid'
            end
        endcase
    end

endmodule
