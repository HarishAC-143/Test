// ----------------------------------------------------------------------------
// Systolic Array Matrix Multiplier
// Demonstrates: systolic data flow, processing element (PE) arrays,
//               generate-based 2D array, wavefront computation
// Computes: C = A x B for N x N matrices
// ----------------------------------------------------------------------------

module systolic_pe #(
    parameter int DATA_WIDTH = 16,
    parameter int ACC_WIDTH  = 48
)(
    input  logic                           clk,
    input  logic                           rst_n,
    input  logic                           clear,

    // Data flowing right (A elements)
    input  logic signed [DATA_WIDTH-1:0]   a_in,
    output logic signed [DATA_WIDTH-1:0]   a_out,

    // Data flowing down (B elements)
    input  logic signed [DATA_WIDTH-1:0]   b_in,
    output logic signed [DATA_WIDTH-1:0]   b_out,

    // Accumulated result
    output logic signed [ACC_WIDTH-1:0]    c_out
);

    logic signed [ACC_WIDTH-1:0] accumulator;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            a_out       <= '0;
            b_out       <= '0;
            accumulator <= '0;
        end else if (clear) begin
            accumulator <= '0;
        end else begin
            // Pass data through to neighbors
            a_out <= a_in;
            b_out <= b_in;

            // Multiply and accumulate
            accumulator <= accumulator + (ACC_WIDTH'(a_in) * ACC_WIDTH'(b_in));
        end
    end

    assign c_out = accumulator;

endmodule


module systolic_matrix_multiplier #(
    parameter int N          = 4,    // Matrix dimension (N x N)
    parameter int DATA_WIDTH = 16,
    parameter int ACC_WIDTH  = 48
)(
    input  logic                           clk,
    input  logic                           rst_n,
    input  logic                           clear,

    // Skewed input data (pre-skewed by the feeder)
    input  logic signed [DATA_WIDTH-1:0]   a_row [N],   // One element per row, fed left-to-right
    input  logic signed [DATA_WIDTH-1:0]   b_col [N],   // One element per column, fed top-to-bottom

    // Result matrix (available after 2N-1 cycles)
    output logic signed [ACC_WIDTH-1:0]    c_result [N][N],
    output logic                           result_valid
);

    // Internal wiring between PEs
    logic signed [DATA_WIDTH-1:0] a_wire [N][N+1];
    logic signed [DATA_WIDTH-1:0] b_wire [N+1][N];

    // Connect inputs to leftmost column (A) and topmost row (B)
    generate
        for (genvar r = 0; r < N; r++) begin : gen_a_input
            assign a_wire[r][0] = a_row[r];
        end

        for (genvar c = 0; c < N; c++) begin : gen_b_input
            assign b_wire[0][c] = b_col[c];
        end
    endgenerate

    // Instantiate N x N PE array
    generate
        for (genvar r = 0; r < N; r++) begin : gen_row
            for (genvar c = 0; c < N; c++) begin : gen_col
                systolic_pe #(
                    .DATA_WIDTH (DATA_WIDTH),
                    .ACC_WIDTH  (ACC_WIDTH)
                ) u_pe (
                    .clk   (clk),
                    .rst_n (rst_n),
                    .clear (clear),
                    .a_in  (a_wire[r][c]),
                    .a_out (a_wire[r][c+1]),
                    .b_in  (b_wire[r][c]),
                    .b_out (b_wire[r+1][c]),
                    .c_out (c_result[r][c])
                );
            end
        end
    endgenerate

    // Result validity counter: valid after 2N-1 cycles of feeding data
    logic [$clog2(3*N):0] cycle_cnt;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n || clear) begin
            cycle_cnt    <= '0;
            result_valid <= 1'b0;
        end else begin
            if (cycle_cnt < 2*N - 1)
                cycle_cnt <= cycle_cnt + 1'b1;
            else
                result_valid <= 1'b1;
        end
    end

endmodule


// ===== Data Skewing Unit =====
// Converts row-parallel input to the skewed format required by the systolic array
module input_skewer #(
    parameter int N          = 4,
    parameter int DATA_WIDTH = 16
)(
    input  logic                          clk,
    input  logic                          rst_n,
    input  logic                          load,
    input  logic signed [DATA_WIDTH-1:0]  matrix_in [N][N],
    output logic signed [DATA_WIDTH-1:0]  skewed_out [N],
    output logic                          feeding
);

    logic signed [DATA_WIDTH-1:0] buffer [N][2*N];
    logic [$clog2(2*N):0] feed_cnt;

    // Load and skew: row i is delayed by i cycles
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            feed_cnt <= '0;
            feeding  <= 1'b0;
            for (int r = 0; r < N; r++)
                for (int c = 0; c < 2*N; c++)
                    buffer[r][c] <= '0;
        end else if (load) begin
            // Load with appropriate delays (zeros before data)
            for (int r = 0; r < N; r++) begin
                for (int c = 0; c < 2*N; c++) begin
                    if (c >= r && c < r + N)
                        buffer[r][c] <= matrix_in[r][c - r];
                    else
                        buffer[r][c] <= '0;
                end
            end
            feed_cnt <= '0;
            feeding  <= 1'b1;
        end else if (feeding) begin
            if (feed_cnt < 2*N - 1)
                feed_cnt <= feed_cnt + 1'b1;
            else
                feeding <= 1'b0;
        end
    end

    // Output one column at a time
    always_comb begin
        for (int r = 0; r < N; r++)
            skewed_out[r] = feeding ? buffer[r][feed_cnt] : '0;
    end

endmodule
