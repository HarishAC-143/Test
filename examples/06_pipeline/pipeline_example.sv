// 3-Stage Pipeline: Fetch -> Execute -> Writeback
// Demonstrates pipelining concept with pipeline registers

module pipeline_3stage #(
    parameter DATA_WIDTH = 16
)(
    input  logic                    clk,
    input  logic                    rst_n,
    input  logic                    valid_in,
    input  logic [DATA_WIDTH-1:0]   data_a_in,
    input  logic [DATA_WIDTH-1:0]   data_b_in,
    input  logic [1:0]              op_in,       // 00=add, 01=sub, 10=and, 11=or
    output logic [DATA_WIDTH-1:0]   result_out,
    output logic                    valid_out
);

    // --- Pipeline Stage 1: Input Registration (Fetch) ---
    logic [DATA_WIDTH-1:0] s1_data_a, s1_data_b;
    logic [1:0]            s1_op;
    logic                  s1_valid;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s1_data_a <= '0;
            s1_data_b <= '0;
            s1_op     <= '0;
            s1_valid  <= 1'b0;
        end else begin
            s1_data_a <= data_a_in;
            s1_data_b <= data_b_in;
            s1_op     <= op_in;
            s1_valid  <= valid_in;
        end
    end

    // --- Pipeline Stage 2: Compute (Execute) ---
    logic [DATA_WIDTH-1:0] s2_result;
    logic                  s2_valid;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s2_result <= '0;
            s2_valid  <= 1'b0;
        end else begin
            s2_valid <= s1_valid;
            case (s1_op)
                2'b00:   s2_result <= s1_data_a + s1_data_b;
                2'b01:   s2_result <= s1_data_a - s1_data_b;
                2'b10:   s2_result <= s1_data_a & s1_data_b;
                2'b11:   s2_result <= s1_data_a | s1_data_b;
                default: s2_result <= '0;
            endcase
        end
    end

    // --- Pipeline Stage 3: Output Registration (Writeback) ---
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result_out <= '0;
            valid_out  <= 1'b0;
        end else begin
            result_out <= s2_result;
            valid_out  <= s2_valid;
        end
    end

endmodule


// Pipeline with stall and flush support
module pipeline_with_hazards #(
    parameter WIDTH = 32
)(
    input  logic             clk,
    input  logic             rst_n,
    input  logic             stall,       // Hold pipeline
    input  logic             flush,       // Clear pipeline

    input  logic [WIDTH-1:0] data_in,
    input  logic             valid_in,

    output logic [WIDTH-1:0] stage1_out,
    output logic [WIDTH-1:0] stage2_out,
    output logic [WIDTH-1:0] stage3_out,
    output logic             valid_out
);

    logic valid_s1, valid_s2;

    // Stage 1
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            stage1_out <= '0;
            valid_s1   <= 1'b0;
        end else if (flush) begin
            stage1_out <= '0;
            valid_s1   <= 1'b0;
        end else if (!stall) begin
            stage1_out <= data_in;
            valid_s1   <= valid_in;
        end
    end

    // Stage 2: some processing
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            stage2_out <= '0;
            valid_s2   <= 1'b0;
        end else if (flush) begin
            stage2_out <= '0;
            valid_s2   <= 1'b0;
        end else if (!stall) begin
            stage2_out <= stage1_out + 32'd1;
            valid_s2   <= valid_s1;
        end
    end

    // Stage 3: output
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            stage3_out <= '0;
            valid_out  <= 1'b0;
        end else if (flush) begin
            stage3_out <= '0;
            valid_out  <= 1'b0;
        end else if (!stall) begin
            stage3_out <= stage2_out << 1;
            valid_out  <= valid_s2;
        end
    end

endmodule
