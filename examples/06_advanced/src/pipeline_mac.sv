// Pipelined Multiply-Accumulate (MAC) Unit
// Three-stage pipeline for high-throughput computation:
//   Stage 1: Register inputs
//   Stage 2: Multiply
//   Stage 3: Accumulate
// Achieves one result per clock cycle after pipeline fill.

module pipeline_mac #(
    parameter A_WIDTH   = 16,
    parameter B_WIDTH   = 16,
    parameter ACC_WIDTH = 40
)(
    input  logic                    clk,
    input  logic                    rst_n,
    input  logic                    clear_acc,   // reset accumulator
    input  logic                    valid_in,    // input valid strobe
    input  logic [A_WIDTH-1:0]      a,
    input  logic [B_WIDTH-1:0]      b,
    output logic [ACC_WIDTH-1:0]    acc_out,
    output logic                    valid_out
);

    localparam PROD_WIDTH = A_WIDTH + B_WIDTH;

    // Pipeline registers
    // Stage 1: input capture
    logic signed [A_WIDTH-1:0]   a_s1;
    logic signed [B_WIDTH-1:0]   b_s1;
    logic                        valid_s1;
    logic                        clear_s1;

    // Stage 2: multiply
    logic signed [PROD_WIDTH-1:0] product_s2;
    logic                         valid_s2;
    logic                         clear_s2;

    // Stage 3: accumulate
    logic signed [ACC_WIDTH-1:0]  accumulator;
    logic                         valid_s3;

    // Stage 1
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            a_s1     <= '0;
            b_s1     <= '0;
            valid_s1 <= 1'b0;
            clear_s1 <= 1'b0;
        end else begin
            a_s1     <= $signed(a);
            b_s1     <= $signed(b);
            valid_s1 <= valid_in;
            clear_s1 <= clear_acc;
        end
    end

    // Stage 2
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            product_s2 <= '0;
            valid_s2   <= 1'b0;
            clear_s2   <= 1'b0;
        end else begin
            product_s2 <= a_s1 * b_s1;
            valid_s2   <= valid_s1;
            clear_s2   <= clear_s1;
        end
    end

    // Stage 3
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            accumulator <= '0;
            valid_s3    <= 1'b0;
        end else begin
            valid_s3 <= valid_s2;
            if (clear_s2)
                accumulator <= ACC_WIDTH'(product_s2);
            else if (valid_s2)
                accumulator <= accumulator + ACC_WIDTH'(product_s2);
        end
    end

    assign acc_out   = accumulator;
    assign valid_out = valid_s3;

endmodule
