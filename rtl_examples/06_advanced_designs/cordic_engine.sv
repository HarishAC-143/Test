// =============================================================================
// CORDIC Engine — Iterative Sine/Cosine Calculator
// Computes sin(theta) and cos(theta) using the CORDIC algorithm.
// Uses fixed-point representation with configurable precision.
// =============================================================================

module cordic_engine #(
    parameter DATA_WIDTH  = 16,
    parameter NUM_ITERS   = 14,    // Number of CORDIC iterations
    parameter ANGLE_WIDTH = 32     // Angle input width (fixed-point)
) (
    input  logic                       clk,
    input  logic                       rst_n,
    input  logic                       start,
    input  logic signed [ANGLE_WIDTH-1:0] angle_in,  // Input angle in radians (fixed-point)
    output logic signed [DATA_WIDTH-1:0]  cos_out,
    output logic signed [DATA_WIDTH-1:0]  sin_out,
    output logic                       done,
    output logic                       busy
);

    // CORDIC arctangent lookup table (pre-computed, fixed-point)
    // atan(2^-i) for i = 0..NUM_ITERS-1
    logic signed [ANGLE_WIDTH-1:0] atan_table [NUM_ITERS];

    initial begin
        atan_table[0]  = 32'sd823549964;   // atan(2^0)  = 45.0 deg
        atan_table[1]  = 32'sd486476681;   // atan(2^-1) = 26.565 deg
        atan_table[2]  = 32'sd256970781;   // atan(2^-2) = 14.036 deg
        atan_table[3]  = 32'sd130449707;   // atan(2^-3) = 7.125 deg
        atan_table[4]  = 32'sd65496686;    // atan(2^-4)
        atan_table[5]  = 32'sd32776035;    // atan(2^-5)
        atan_table[6]  = 32'sd16389106;    // atan(2^-6)
        atan_table[7]  = 32'sd8194688;     // atan(2^-7)
        atan_table[8]  = 32'sd4097361;     // atan(2^-8)
        atan_table[9]  = 32'sd2048682;     // atan(2^-9)
        atan_table[10] = 32'sd1024341;     // atan(2^-10)
        atan_table[11] = 32'sd512170;      // atan(2^-11)
        atan_table[12] = 32'sd256085;      // atan(2^-12)
        atan_table[13] = 32'sd128043;      // atan(2^-13)
    end

    // CORDIC gain compensation: K = product of 1/sqrt(1+2^-2i) ~ 0.6073
    localparam signed [DATA_WIDTH-1:0] K_FACTOR = DATA_WIDTH'(16'sd19898);  // 0.6073 * 2^15

    typedef enum logic [1:0] {
        IDLE     = 2'b00,
        COMPUTE  = 2'b01,
        FINISHED = 2'b10
    } state_e;

    state_e state;
    logic [$clog2(NUM_ITERS)-1:0] iteration;
    logic signed [DATA_WIDTH-1:0] x, y;
    logic signed [ANGLE_WIDTH-1:0] z;

    assign busy = (state != IDLE);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= IDLE;
            x         <= '0;
            y         <= '0;
            z         <= '0;
            iteration <= '0;
            cos_out   <= '0;
            sin_out   <= '0;
            done      <= 1'b0;
        end else begin
            done <= 1'b0;

            case (state)
                IDLE: begin
                    if (start) begin
                        // Initialize: x=K, y=0, z=angle
                        x         <= K_FACTOR;
                        y         <= '0;
                        z         <= angle_in;
                        iteration <= '0;
                        state     <= COMPUTE;
                    end
                end

                COMPUTE: begin
                    if (z >= 0) begin
                        x <= x - (y >>> iteration);
                        y <= y + (x >>> iteration);
                        z <= z - atan_table[iteration];
                    end else begin
                        x <= x + (y >>> iteration);
                        y <= y - (x >>> iteration);
                        z <= z + atan_table[iteration];
                    end

                    if (iteration == NUM_ITERS[$clog2(NUM_ITERS)-1:0] - 1) begin
                        state <= FINISHED;
                    end else begin
                        iteration <= iteration + 1'b1;
                    end
                end

                FINISHED: begin
                    cos_out <= x;
                    sin_out <= y;
                    done    <= 1'b1;
                    state   <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
