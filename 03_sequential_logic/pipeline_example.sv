// Multi-stage pipeline example.
// Demonstrates how to break a computation into stages to meet timing.
//
// This example computes: result = (a * b) + c
// Stage 1: multiply a * b
// Stage 2: add c to the product

module pipeline_example #(
    parameter int WIDTH = 16
)(
    input  logic               clk,
    input  logic               rst_n,
    input  logic               valid_in,
    input  logic [WIDTH-1:0]   a,
    input  logic [WIDTH-1:0]   b,
    input  logic [WIDTH-1:0]   c,
    output logic               valid_out,
    output logic [2*WIDTH-1:0] result
);

    // Stage 1 registers
    logic [2*WIDTH-1:0] product_s1;
    logic [WIDTH-1:0]   c_s1;
    logic               valid_s1;

    // Stage 2 registers
    logic [2*WIDTH-1:0] result_s2;
    logic               valid_s2;

    // Stage 1: Multiply
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            product_s1 <= '0;
            c_s1       <= '0;
            valid_s1   <= 1'b0;
        end else begin
            product_s1 <= a * b;
            c_s1       <= c;
            valid_s1   <= valid_in;
        end
    end

    // Stage 2: Add
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result_s2 <= '0;
            valid_s2  <= 1'b0;
        end else begin
            result_s2 <= product_s1 + {{WIDTH{1'b0}}, c_s1};
            valid_s2  <= valid_s1;
        end
    end

    assign result    = result_s2;
    assign valid_out = valid_s2;

endmodule
