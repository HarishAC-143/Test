// Pipelined Datapath with Multicycle Paths
// Demonstrates: Pipeline stages and multicycle path constraints

module pipeline #(
    parameter DATA_WIDTH = 16
)(
    input  wire                   clk,
    input  wire                   rst_n,

    // Input interface
    input  wire [DATA_WIDTH-1:0]  data_a,
    input  wire [DATA_WIDTH-1:0]  data_b,
    input  wire                   input_valid,

    // Configuration (static, set once at boot)
    input  wire [3:0]             config_mode,
    input  wire                   config_bypass,

    // Output interface
    output reg  [DATA_WIDTH-1:0]  result,
    output reg                    output_valid,

    // Slow status interface (updated every 4th cycle)
    output reg  [7:0]             status_count,
    output reg                    status_overflow
);

    // Pipeline Stage 1: Input registration
    reg [DATA_WIDTH-1:0] pipe1_a, pipe1_b;
    reg                  pipe1_valid;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pipe1_a     <= {DATA_WIDTH{1'b0}};
            pipe1_b     <= {DATA_WIDTH{1'b0}};
            pipe1_valid <= 1'b0;
        end else begin
            pipe1_a     <= data_a;
            pipe1_b     <= data_b;
            pipe1_valid <= input_valid;
        end
    end

    // Pipeline Stage 2: Arithmetic (add/subtract based on config)
    reg [DATA_WIDTH-1:0] pipe2_result;
    reg                  pipe2_valid;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pipe2_result <= {DATA_WIDTH{1'b0}};
            pipe2_valid  <= 1'b0;
        end else begin
            case (config_mode[1:0])
                2'b00: pipe2_result <= pipe1_a + pipe1_b;
                2'b01: pipe2_result <= pipe1_a - pipe1_b;
                2'b10: pipe2_result <= pipe1_a & pipe1_b;
                2'b11: pipe2_result <= pipe1_a | pipe1_b;
            endcase
            pipe2_valid <= pipe1_valid;
        end
    end

    // Pipeline Stage 3: Post-processing (shift/saturate)
    reg [DATA_WIDTH-1:0] pipe3_result;
    reg                  pipe3_valid;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pipe3_result <= {DATA_WIDTH{1'b0}};
            pipe3_valid  <= 1'b0;
        end else begin
            if (config_mode[2])
                pipe3_result <= pipe2_result >> config_mode[3:2];
            else
                pipe3_result <= pipe2_result;
            pipe3_valid <= pipe2_valid;
        end
    end

    // Output stage with optional bypass
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result       <= {DATA_WIDTH{1'b0}};
            output_valid <= 1'b0;
        end else begin
            result       <= config_bypass ? pipe1_a : pipe3_result;
            output_valid <= config_bypass ? pipe1_valid : pipe3_valid;
        end
    end

    // Slow status counter (updates every 4 clock cycles)
    reg [1:0] status_div;
    reg [7:0] count_accum;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            status_div      <= 2'd0;
            count_accum     <= 8'd0;
            status_count    <= 8'd0;
            status_overflow <= 1'b0;
        end else begin
            if (pipe3_valid)
                count_accum <= count_accum + 1'b1;

            status_div <= status_div + 1'b1;

            if (status_div == 2'd3) begin
                status_count    <= count_accum;
                status_overflow <= (count_accum == 8'hFF);
            end
        end
    end

endmodule
