// Pipeline Design Examples
// Pipelining increases throughput by breaking combinational paths into stages.
// Each stage completes in one clock cycle, and all stages execute concurrently.

// Generic N-stage pipeline with valid propagation
module pipeline_stage #(
    parameter int DATA_WIDTH = 32,
    parameter int NUM_STAGES = 4
) (
    input  logic                  clk,
    input  logic                  rst_n,
    input  logic                  enable,
    input  logic [DATA_WIDTH-1:0] data_in,
    input  logic                  valid_in,
    output logic [DATA_WIDTH-1:0] data_out,
    output logic                  valid_out
);

    logic [DATA_WIDTH-1:0] stage_data  [NUM_STAGES];
    logic                  stage_valid [NUM_STAGES];

    // Pipeline stages
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < NUM_STAGES; i++) begin
                stage_data[i]  <= '0;
                stage_valid[i] <= 1'b0;
            end
        end else if (enable) begin
            stage_data[0]  <= data_in;
            stage_valid[0] <= valid_in;
            for (int i = 1; i < NUM_STAGES; i++) begin
                stage_data[i]  <= stage_data[i-1];
                stage_valid[i] <= stage_valid[i-1];
            end
        end
    end

    assign data_out  = stage_data[NUM_STAGES-1];
    assign valid_out = stage_valid[NUM_STAGES-1];

endmodule


// Pipelined Multiply-Accumulate (MAC) Unit
// Common in DSP and neural network accelerators
// Pipeline: Stage 1 = Multiply, Stage 2 = Accumulate
module pipelined_mac #(
    parameter int A_WIDTH   = 16,
    parameter int B_WIDTH   = 16,
    parameter int ACC_WIDTH = 48
) (
    input  logic                   clk,
    input  logic                   rst_n,
    input  logic                   clear_acc,
    input  logic                   valid_in,
    input  logic [A_WIDTH-1:0]     a,
    input  logic [B_WIDTH-1:0]     b,
    output logic [ACC_WIDTH-1:0]   accumulator,
    output logic                   valid_out
);

    localparam int PROD_WIDTH = A_WIDTH + B_WIDTH;

    // Stage 1: Multiply
    logic [PROD_WIDTH-1:0] product;
    logic                  s1_valid;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            product  <= '0;
            s1_valid <= 1'b0;
        end else begin
            product  <= $signed(a) * $signed(b);
            s1_valid <= valid_in;
        end
    end

    // Stage 2: Accumulate
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            accumulator <= '0;
            valid_out   <= 1'b0;
        end else begin
            valid_out <= s1_valid;
            if (clear_acc)
                accumulator <= '0;
            else if (s1_valid)
                accumulator <= accumulator + {{(ACC_WIDTH-PROD_WIDTH){product[PROD_WIDTH-1]}}, product};
        end
    end

endmodule


// Pipelined data processor with backpressure (valid/ready handshake)
module pipeline_with_backpressure #(
    parameter int WIDTH = 32
) (
    input  logic             clk,
    input  logic             rst_n,

    // Input interface
    input  logic [WIDTH-1:0] in_data,
    input  logic             in_valid,
    output logic             in_ready,

    // Output interface
    output logic [WIDTH-1:0] out_data,
    output logic             out_valid,
    input  logic             out_ready
);

    // Stage 1 registers
    logic [WIDTH-1:0] s1_data;
    logic             s1_valid;

    // Stage 2 registers
    logic [WIDTH-1:0] s2_data;
    logic             s2_valid;

    // Backpressure: each stage can accept when it's empty or its output is consumed
    wire s2_ready = !s2_valid || out_ready;
    wire s1_ready = !s1_valid || s2_ready;
    assign in_ready = s1_ready;

    // Stage 1: Input registration + some processing
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s1_data  <= '0;
            s1_valid <= 1'b0;
        end else begin
            if (s1_ready) begin
                s1_data  <= in_data + 1'b1;
                s1_valid <= in_valid;
            end
        end
    end

    // Stage 2: Further processing
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s2_data  <= '0;
            s2_valid <= 1'b0;
        end else begin
            if (s2_ready) begin
                s2_data  <= s1_data << 1;
                s2_valid <= s1_valid;
            end
        end
    end

    assign out_data  = s2_data;
    assign out_valid = s2_valid;

endmodule
