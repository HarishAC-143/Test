// ============================================================================
// Pipeline Register with Flush and Enable
// ============================================================================
// A general-purpose pipeline stage register used between pipeline stages.
// Supports:
//   - Parameterized width
//   - Clock enable (stall support)
//   - Synchronous flush (pipeline bubble insertion)
//   - Configurable reset value
//
// Also demonstrates a type-parameterized variant below.
// ============================================================================

module pipe_reg #(
    parameter int WIDTH     = 32,
    parameter bit RESET_VAL = 1'b0
)(
    input  logic             clk,
    input  logic             rst_n,
    input  logic             en,
    input  logic             flush,
    input  logic [WIDTH-1:0] d,
    output logic [WIDTH-1:0] q
);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            q <= {WIDTH{RESET_VAL}};
        else if (flush)
            q <= {WIDTH{RESET_VAL}};
        else if (en)
            q <= d;
    end

endmodule


// ============================================================================
// Type-Parameterized Register
// ============================================================================
// Instead of parameterizing the width, parameterize the type itself.
// This works with structs, enums, or any user-defined type.
// ============================================================================

module typed_register #(
    parameter type T = logic [7:0]
)(
    input  logic clk,
    input  logic rst_n,
    input  logic en,
    input  T     d,
    output T     q
);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            q <= T'(0);
        else if (en)
            q <= d;
    end

endmodule
