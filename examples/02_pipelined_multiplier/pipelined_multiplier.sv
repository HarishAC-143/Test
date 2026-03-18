// 4-Stage Pipelined Unsigned Multiplier
// Splits an N-bit multiplication across 4 pipeline stages for high throughput.
// Produces one result per clock cycle after an initial 4-cycle latency.

module pipelined_multiplier #(
    parameter int WIDTH = 16
) (
    input  logic                 clk,
    input  logic                 rst_n,
    input  logic                 valid_in,
    input  logic [WIDTH-1:0]     operand_a,
    input  logic [WIDTH-1:0]     operand_b,
    output logic                 valid_out,
    output logic [2*WIDTH-1:0]   product
);

    localparam int HALF = WIDTH / 2;

    // Stage 1: Input registration and operand splitting
    logic                 s1_valid;
    logic [HALF-1:0]      s1_a_lo, s1_a_hi;
    logic [HALF-1:0]      s1_b_lo, s1_b_hi;

    // Stage 2: Partial product generation
    logic                 s2_valid;
    logic [2*HALF-1:0]    s2_pp_ll;  // a_lo * b_lo
    logic [2*HALF-1:0]    s2_pp_lh;  // a_lo * b_hi
    logic [2*HALF-1:0]    s2_pp_hl;  // a_hi * b_lo
    logic [2*HALF-1:0]    s2_pp_hh;  // a_hi * b_hi

    // Stage 3: Partial product accumulation
    logic                 s3_valid;
    logic [2*WIDTH-1:0]   s3_sum;

    // Stage 4: Output registration
    logic                 s4_valid;
    logic [2*WIDTH-1:0]   s4_product;

    // --- Stage 1: Register inputs and split operands ---
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s1_valid <= 1'b0;
            s1_a_lo  <= '0;
            s1_a_hi  <= '0;
            s1_b_lo  <= '0;
            s1_b_hi  <= '0;
        end else begin
            s1_valid <= valid_in;
            s1_a_lo  <= operand_a[HALF-1:0];
            s1_a_hi  <= operand_a[WIDTH-1:HALF];
            s1_b_lo  <= operand_b[HALF-1:0];
            s1_b_hi  <= operand_b[WIDTH-1:HALF];
        end
    end

    // --- Stage 2: Compute partial products ---
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s2_valid <= 1'b0;
            s2_pp_ll <= '0;
            s2_pp_lh <= '0;
            s2_pp_hl <= '0;
            s2_pp_hh <= '0;
        end else begin
            s2_valid <= s1_valid;
            s2_pp_ll <= s1_a_lo * s1_b_lo;
            s2_pp_lh <= s1_a_lo * s1_b_hi;
            s2_pp_hl <= s1_a_hi * s1_b_lo;
            s2_pp_hh <= s1_a_hi * s1_b_hi;
        end
    end

    // --- Stage 3: Accumulate partial products ---
    // product = pp_hh << (2*HALF) + (pp_lh + pp_hl) << HALF + pp_ll
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s3_valid <= 1'b0;
            s3_sum   <= '0;
        end else begin
            s3_valid <= s2_valid;
            s3_sum   <= ({s2_pp_hh, {(2*HALF){1'b0}}}) +
                        ({s2_pp_lh, {HALF{1'b0}}})      +
                        ({s2_pp_hl, {HALF{1'b0}}})      +
                        ({{(2*HALF){1'b0}}, s2_pp_ll});
        end
    end

    // --- Stage 4: Output registration ---
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s4_valid   <= 1'b0;
            s4_product <= '0;
        end else begin
            s4_valid   <= s3_valid;
            s4_product <= s3_sum;
        end
    end

    assign valid_out = s4_valid;
    assign product   = s4_product;

endmodule
