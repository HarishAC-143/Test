// =============================================================================
// SpyGlass Lint Fix: Inferred Latch (W15) — Corrected
// =============================================================================
//
// All combinational always blocks now have complete if/case coverage,
// preventing latch inference during synthesis.
// =============================================================================

module priority_encoder_fixed (
    input  [3:0] req,
    output reg [1:0] grant
);

    always @(*) begin
        if (req[3])
            grant = 2'b11;
        else if (req[2])
            grant = 2'b10;
        else if (req[1])
            grant = 2'b01;
        else
            grant = 2'b00;  // Default prevents latch
    end

endmodule


module alu_fixed (
    input  [1:0] op,
    input  [7:0] a, b,
    output reg [7:0] result
);

    always @(*) begin
        case (op)
            2'b00:   result = a + b;
            2'b01:   result = a - b;
            2'b10:   result = a & b;
            default: result = a ^ b;  // Default covers all remaining values
        endcase
    end

endmodule


module decoder_fixed (
    input  [1:0] sel,
    output reg       valid,
    output reg [3:0] decoded
);

    // Assign defaults at the top of the always block.
    // This guarantees every output is assigned on every path.
    always @(*) begin
        valid   = 1'b0;
        decoded = 4'b0000;

        case (sel)
            2'b00: begin decoded = 4'b0001; valid = 1'b1; end
            2'b01: begin decoded = 4'b0010; valid = 1'b1; end
            2'b10: begin decoded = 4'b0100; valid = 1'b1; end
            default: begin
                decoded = 4'b0000;
                valid   = 1'b0;
            end
        endcase
    end

endmodule
