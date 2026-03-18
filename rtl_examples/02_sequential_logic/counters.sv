// =============================================================================
// Parameterized Up/Down Counter with Load and Enable
// =============================================================================

module updown_counter #(
    parameter WIDTH = 8
) (
    input  logic              clk,
    input  logic              rst_n,
    input  logic              enable,
    input  logic              up_down,     // 1 = up, 0 = down
    input  logic              load,
    input  logic [WIDTH-1:0]  load_value,
    output logic [WIDTH-1:0]  count,
    output logic              overflow,
    output logic              underflow
);

    logic [WIDTH-1:0] next_count;

    always_comb begin
        next_count = count;
        overflow   = 1'b0;
        underflow  = 1'b0;

        if (load) begin
            next_count = load_value;
        end else if (enable) begin
            if (up_down) begin
                {overflow, next_count} = {1'b0, count} + 1'b1;
            end else begin
                next_count = count - 1'b1;
                underflow  = (count == '0);
            end
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            count <= '0;
        else
            count <= next_count;
    end

endmodule

// =============================================================================
// Gray Code Counter
// Outputs a Gray-coded count sequence — useful in CDC (clock domain crossing).
// =============================================================================

module gray_counter #(
    parameter WIDTH = 4
) (
    input  logic              clk,
    input  logic              rst_n,
    input  logic              enable,
    output logic [WIDTH-1:0]  gray_count,
    output logic [WIDTH-1:0]  binary_count
);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            binary_count <= '0;
        else if (enable)
            binary_count <= binary_count + 1'b1;
    end

    assign gray_count = binary_count ^ (binary_count >> 1);

endmodule

// =============================================================================
// Ring Counter — only one bit active at a time, rotating
// =============================================================================

module ring_counter #(
    parameter WIDTH = 8
) (
    input  logic              clk,
    input  logic              rst_n,
    input  logic              enable,
    output logic [WIDTH-1:0]  ring_out
);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            ring_out <= {{(WIDTH-1){1'b0}}, 1'b1};
        else if (enable)
            ring_out <= {ring_out[WIDTH-2:0], ring_out[WIDTH-1]};
    end

endmodule

// =============================================================================
// Johnson Counter — twisted ring counter (complement feedback)
// =============================================================================

module johnson_counter #(
    parameter WIDTH = 4
) (
    input  logic              clk,
    input  logic              rst_n,
    input  logic              enable,
    output logic [WIDTH-1:0]  johnson_out
);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            johnson_out <= '0;
        else if (enable)
            johnson_out <= {johnson_out[WIDTH-2:0], ~johnson_out[WIDTH-1]};
    end

endmodule
