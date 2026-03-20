// ============================================================================
// Pipelined Multiply-Accumulate (MAC) Unit
// ============================================================================
// A 3-stage pipeline that computes acc += a * b each cycle:
//   Stage 1: Input registration
//   Stage 2: Multiplication
//   Stage 3: Accumulation
//
// Pipelining increases throughput to 1 result/cycle at the cost of
// 3 cycles of latency. The `valid` signal propagates through the pipeline
// to indicate when the output is meaningful.
// ============================================================================

module pipelined_mac #(
    parameter int A_WIDTH   = 16,
    parameter int B_WIDTH   = 16,
    parameter int ACC_WIDTH = 48
)(
    input  logic                  clk,
    input  logic                  rst_n,
    input  logic                  valid_in,
    input  logic                  clear,
    input  logic [A_WIDTH-1:0]    a,
    input  logic [B_WIDTH-1:0]    b,
    output logic [ACC_WIDTH-1:0]  acc_out,
    output logic                  valid_out
);

    // --- Stage 1: Input Registration ---
    logic [A_WIDTH-1:0]  a_s1;
    logic [B_WIDTH-1:0]  b_s1;
    logic                valid_s1;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            a_s1     <= '0;
            b_s1     <= '0;
            valid_s1 <= 1'b0;
        end else begin
            a_s1     <= a;
            b_s1     <= b;
            valid_s1 <= valid_in;
        end
    end

    // --- Stage 2: Multiplication ---
    logic [A_WIDTH+B_WIDTH-1:0] product_s2;
    logic                       valid_s2;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            product_s2 <= '0;
            valid_s2   <= 1'b0;
        end else begin
            product_s2 <= a_s1 * b_s1;
            valid_s2   <= valid_s1;
        end
    end

    // --- Stage 3: Accumulation ---
    logic [ACC_WIDTH-1:0] accumulator;
    logic                 valid_s3;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            accumulator <= '0;
            valid_s3    <= 1'b0;
        end else if (clear) begin
            accumulator <= '0;
            valid_s3    <= 1'b0;
        end else begin
            if (valid_s2)
                accumulator <= accumulator + ACC_WIDTH'(product_s2);
            valid_s3 <= valid_s2;
        end
    end

    assign acc_out   = accumulator;
    assign valid_out = valid_s3;

endmodule
