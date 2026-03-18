// =============================================================================
// Radix-4 Booth Multiplier (Sequential)
// Demonstrates: Booth's algorithm, sequential multiplication, signed arithmetic
// =============================================================================

module booth_multiplier #(
    parameter int WIDTH = 16
) (
    input  logic               clk,
    input  logic               rst_n,
    input  logic               start,
    input  logic [WIDTH-1:0]   multiplicand,
    input  logic [WIDTH-1:0]   multiplier,
    output logic [2*WIDTH-1:0] product,
    output logic               done,
    output logic               busy
);

    localparam int ITERATIONS = WIDTH / 2;

    typedef enum logic [1:0] {
        IDLE,
        COMPUTE,
        FINISH
    } state_e;

    state_e state;

    logic [2*WIDTH:0]   accumulator;  // Extra bit for Booth encoding
    logic [WIDTH-1:0]   m_reg;        // Multiplicand register
    logic [$clog2(ITERATIONS):0] iter_count;

    logic [2:0] booth_bits;
    logic signed [WIDTH:0] partial_product;

    // Booth radix-4 encoding: examine 3 bits at a time
    always_comb begin
        booth_bits = accumulator[2:0];
        partial_product = '0;

        unique case (booth_bits)
            3'b000: partial_product = '0;                              //  0
            3'b001: partial_product = $signed({m_reg[WIDTH-1], m_reg}); // +M
            3'b010: partial_product = $signed({m_reg[WIDTH-1], m_reg}); // +M
            3'b011: partial_product = $signed({m_reg[WIDTH-1], m_reg}) <<< 1; // +2M
            3'b100: partial_product = -($signed({m_reg[WIDTH-1], m_reg}) <<< 1); // -2M
            3'b101: partial_product = -$signed({m_reg[WIDTH-1], m_reg}); // -M
            3'b110: partial_product = -$signed({m_reg[WIDTH-1], m_reg}); // -M
            3'b111: partial_product = '0;                              //  0
        endcase
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state       <= IDLE;
            accumulator <= '0;
            m_reg       <= '0;
            iter_count  <= '0;
            product     <= '0;
            done        <= 1'b0;
            busy        <= 1'b0;
        end else begin
            done <= 1'b0;

            unique case (state)
                IDLE: begin
                    busy <= 1'b0;
                    if (start) begin
                        // Load: {0..0, multiplier, 0} — extra LSB for Booth
                        accumulator <= {{WIDTH{1'b0}}, multiplier, 1'b0};
                        m_reg       <= multiplicand;
                        iter_count  <= '0;
                        busy        <= 1'b1;
                        state       <= COMPUTE;
                    end
                end

                COMPUTE: begin
                    // Add partial product to upper half and arithmetic right shift by 2
                    logic signed [2*WIDTH:0] sum;
                    sum = $signed(accumulator[2*WIDTH:WIDTH+1]) + partial_product;

                    accumulator <= $signed({sum, accumulator[WIDTH:0]}) >>> 2;
                    iter_count  <= iter_count + 1;

                    if (iter_count == ITERATIONS - 1)
                        state <= FINISH;
                end

                FINISH: begin
                    product <= accumulator[2*WIDTH:1]; // Discard extra LSB
                    done    <= 1'b1;
                    state   <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
