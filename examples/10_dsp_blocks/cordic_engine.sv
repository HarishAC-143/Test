// ----------------------------------------------------------------------------
// CORDIC (COordinate Rotation DIgital Computer) Engine
// Demonstrates: iterative algorithm in hardware, fixed-point rotation,
//               pipelined vs. iterative trade-off, LUT-based constants
// Computes: sin(theta), cos(theta) using rotation mode
// ----------------------------------------------------------------------------

module cordic_engine #(
    parameter int DATA_WIDTH  = 16,
    parameter int ITERATIONS  = 14,
    parameter bit PIPELINED   = 1     // 1 = fully pipelined, 0 = iterative
)(
    input  logic                           clk,
    input  logic                           rst_n,
    input  logic signed [DATA_WIDTH-1:0]   angle_in,   // Input angle in fixed-point
    input  logic                           valid_in,

    output logic signed [DATA_WIDTH-1:0]   cos_out,
    output logic signed [DATA_WIDTH-1:0]   sin_out,
    output logic                           valid_out
);

    // CORDIC arctangent lookup table (pre-computed, scaled to DATA_WIDTH)
    // atan(2^-i) values scaled by 2^(DATA_WIDTH-2)
    logic signed [DATA_WIDTH-1:0] atan_table [ITERATIONS];

    // Initialize atan table (values for 16-bit fixed-point)
    initial begin
        atan_table[0]  = 16'sd8192;   // atan(1)     = 45.0°
        atan_table[1]  = 16'sd4836;   // atan(0.5)   = 26.565°
        atan_table[2]  = 16'sd2555;   // atan(0.25)  = 14.036°
        atan_table[3]  = 16'sd1297;   // atan(0.125) = 7.125°
        atan_table[4]  = 16'sd651;    // atan(2^-4)
        atan_table[5]  = 16'sd326;
        atan_table[6]  = 16'sd163;
        atan_table[7]  = 16'sd81;
        atan_table[8]  = 16'sd41;
        atan_table[9]  = 16'sd20;
        atan_table[10] = 16'sd10;
        atan_table[11] = 16'sd5;
        atan_table[12] = 16'sd3;
        atan_table[13] = 16'sd1;
    end

    // CORDIC gain compensation: K = 0.6073 ≈ 0x4DBA (for 16-bit)
    localparam logic signed [DATA_WIDTH-1:0] CORDIC_GAIN = 16'sd19898;

    generate
        if (PIPELINED) begin : gen_pipelined
            // Fully pipelined: one iteration per clock, ITERATIONS pipeline stages
            logic signed [DATA_WIDTH-1:0] x_pipe [ITERATIONS+1];
            logic signed [DATA_WIDTH-1:0] y_pipe [ITERATIONS+1];
            logic signed [DATA_WIDTH-1:0] z_pipe [ITERATIONS+1];
            logic                         v_pipe [ITERATIONS+1];

            // Input stage: initialize to unit vector on X-axis
            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    x_pipe[0] <= '0;
                    y_pipe[0] <= '0;
                    z_pipe[0] <= '0;
                    v_pipe[0] <= 1'b0;
                end else begin
                    x_pipe[0] <= CORDIC_GAIN;
                    y_pipe[0] <= '0;
                    z_pipe[0] <= angle_in;
                    v_pipe[0] <= valid_in;
                end
            end

            for (genvar i = 0; i < ITERATIONS; i++) begin : gen_stage
                always_ff @(posedge clk or negedge rst_n) begin
                    if (!rst_n) begin
                        x_pipe[i+1] <= '0;
                        y_pipe[i+1] <= '0;
                        z_pipe[i+1] <= '0;
                        v_pipe[i+1] <= 1'b0;
                    end else begin
                        v_pipe[i+1] <= v_pipe[i];

                        if (z_pipe[i] >= 0) begin
                            // Rotate counter-clockwise
                            x_pipe[i+1] <= x_pipe[i] - (y_pipe[i] >>> i);
                            y_pipe[i+1] <= y_pipe[i] + (x_pipe[i] >>> i);
                            z_pipe[i+1] <= z_pipe[i] - atan_table[i];
                        end else begin
                            // Rotate clockwise
                            x_pipe[i+1] <= x_pipe[i] + (y_pipe[i] >>> i);
                            y_pipe[i+1] <= y_pipe[i] - (x_pipe[i] >>> i);
                            z_pipe[i+1] <= z_pipe[i] + atan_table[i];
                        end
                    end
                end
            end

            assign cos_out   = x_pipe[ITERATIONS];
            assign sin_out   = y_pipe[ITERATIONS];
            assign valid_out = v_pipe[ITERATIONS];

        end else begin : gen_iterative
            // Iterative: reuse one rotation stage, takes ITERATIONS cycles
            logic signed [DATA_WIDTH-1:0] x_reg, y_reg, z_reg;
            logic [$clog2(ITERATIONS)-1:0] iter_cnt;
            logic                          running;

            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    x_reg     <= '0;
                    y_reg     <= '0;
                    z_reg     <= '0;
                    iter_cnt  <= '0;
                    running   <= 1'b0;
                    valid_out <= 1'b0;
                end else begin
                    valid_out <= 1'b0;

                    if (valid_in && !running) begin
                        x_reg    <= CORDIC_GAIN;
                        y_reg    <= '0;
                        z_reg    <= angle_in;
                        iter_cnt <= '0;
                        running  <= 1'b1;
                    end else if (running) begin
                        if (z_reg >= 0) begin
                            x_reg <= x_reg - (y_reg >>> iter_cnt);
                            y_reg <= y_reg + (x_reg >>> iter_cnt);
                            z_reg <= z_reg - atan_table[iter_cnt];
                        end else begin
                            x_reg <= x_reg + (y_reg >>> iter_cnt);
                            y_reg <= y_reg - (x_reg >>> iter_cnt);
                            z_reg <= z_reg + atan_table[iter_cnt];
                        end

                        if (iter_cnt == ITERATIONS - 1) begin
                            running   <= 1'b0;
                            valid_out <= 1'b1;
                        end else begin
                            iter_cnt <= iter_cnt + 1'b1;
                        end
                    end
                end
            end

            assign cos_out = x_reg;
            assign sin_out = y_reg;
        end
    endgenerate

endmodule
