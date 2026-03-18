// ----------------------------------------------------------------------------
// Multi-Stage Pipelined Multiply-Accumulate (MAC) Unit
// Demonstrates: pipeline registers, hazard-free datapath, parameterized depth,
//               pipeline flush/stall control, valid propagation
// ----------------------------------------------------------------------------

module pipelined_mac #(
    parameter int DATA_WIDTH = 16,
    parameter int ACC_WIDTH  = 48,
    parameter int NUM_STAGES = 3    // Pipeline depth: input-reg, multiply, accumulate
)(
    input  logic                    clk,
    input  logic                    rst_n,
    input  logic                    flush,
    input  logic                    stall,

    input  logic [DATA_WIDTH-1:0]   operand_a,
    input  logic [DATA_WIDTH-1:0]   operand_b,
    input  logic                    valid_in,
    input  logic                    acc_clear,

    output logic [ACC_WIDTH-1:0]    result,
    output logic                    valid_out
);

    // --- Stage 1: Input Registration ---
    logic [DATA_WIDTH-1:0] s1_a, s1_b;
    logic                  s1_valid;
    logic                  s1_acc_clear;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n || flush) begin
            s1_a         <= '0;
            s1_b         <= '0;
            s1_valid     <= 1'b0;
            s1_acc_clear <= 1'b0;
        end else if (!stall) begin
            s1_a         <= operand_a;
            s1_b         <= operand_b;
            s1_valid     <= valid_in;
            s1_acc_clear <= acc_clear;
        end
    end

    // --- Stage 2: Multiplication ---
    logic [2*DATA_WIDTH-1:0] s2_product;
    logic                    s2_valid;
    logic                    s2_acc_clear;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n || flush) begin
            s2_product   <= '0;
            s2_valid     <= 1'b0;
            s2_acc_clear <= 1'b0;
        end else if (!stall) begin
            s2_product   <= $signed(s1_a) * $signed(s1_b);
            s2_valid     <= s1_valid;
            s2_acc_clear <= s1_acc_clear;
        end
    end

    // --- Stage 3: Accumulation ---
    logic [ACC_WIDTH-1:0] accumulator;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n || flush) begin
            accumulator <= '0;
            valid_out   <= 1'b0;
        end else if (!stall) begin
            valid_out <= s2_valid;
            if (s2_acc_clear)
                accumulator <= {{(ACC_WIDTH-2*DATA_WIDTH){s2_product[2*DATA_WIDTH-1]}}, s2_product};
            else if (s2_valid)
                accumulator <= accumulator +
                    {{(ACC_WIDTH-2*DATA_WIDTH){s2_product[2*DATA_WIDTH-1]}}, s2_product};
        end
    end

    assign result = accumulator;

endmodule
