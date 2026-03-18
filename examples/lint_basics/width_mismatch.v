//-----------------------------------------------------------------------------
// Example: Width Mismatch in Assignments and Ports
//
// SpyGlass Rules Triggered:
//   W_164a  - Width mismatch in assignment (truncation)
//   W_164b  - Width mismatch in assignment (zero-extension)
//   W_116   - Potential unintended bit-width behavior
//
// Demonstrates how implicit truncation and extension cause silent
// data corruption that compilers rarely warn about.
//-----------------------------------------------------------------------------

module width_mismatch_bad (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [15:0] wide_data,
    input  wire [7:0]  narrow_data,
    input  wire [3:0]  small_val,
    output reg  [7:0]  result_a,
    output reg  [15:0] result_b,
    output reg  [7:0]  sum
);

    // BUG: Truncation — upper 8 bits of wide_data are silently dropped
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            result_a <= 8'b0;
        else
            result_a <= wide_data;  // W_164a: 16-bit → 8-bit
    end

    // BUG: Zero-extension — narrow_data is silently zero-extended to 16 bits
    // This may be intentional, but SpyGlass flags it for review
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            result_b <= 16'b0;
        else
            result_b <= narrow_data;  // W_164b: 8-bit → 16-bit
    end

    // BUG: Expression width overflow
    // narrow_data + wide_data produces a 16-bit result, truncated to 8 bits
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            sum <= 8'b0;
        else
            sum <= narrow_data + wide_data[7:0] + small_val;
            // Potential overflow: 8 + 8 + 4 bits → max width 9 bits → truncated to 8
    end

endmodule


module width_mismatch_good (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [15:0] wide_data,
    input  wire [7:0]  narrow_data,
    input  wire [3:0]  small_val,
    output reg  [7:0]  result_a,
    output reg  [15:0] result_b,
    output reg  [8:0]  sum          // Widened to avoid overflow
);

    // FIX: Explicit bit-select — intent is clear
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            result_a <= 8'b0;
        else
            result_a <= wide_data[7:0];  // Explicit lower byte extraction
    end

    // FIX: Explicit zero-extension — intent is clear
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            result_b <= 16'b0;
        else
            result_b <= {8'b0, narrow_data};  // Explicit zero-extension
    end

    // FIX: Widen output to accommodate full result
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            sum <= 9'b0;
        else
            sum <= {1'b0, narrow_data} + {1'b0, wide_data[7:0]} + {5'b0, small_val};
    end

endmodule
