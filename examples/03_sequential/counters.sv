// Counter Implementations
// Demonstrates various counter patterns used in FPGA designs

// Up counter with configurable width and terminal count
module up_counter #(
    parameter int WIDTH = 8,
    parameter int MAX_COUNT = (2**WIDTH) - 1
) (
    input  logic             clk,
    input  logic             rst_n,
    input  logic             enable,
    input  logic             clear,
    output logic [WIDTH-1:0] count,
    output logic             terminal_count
);
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            count <= '0;
        else if (clear)
            count <= '0;
        else if (enable) begin
            if (count == MAX_COUNT[WIDTH-1:0])
                count <= '0;
            else
                count <= count + 1'b1;
        end
    end

    assign terminal_count = enable && (count == MAX_COUNT[WIDTH-1:0]);
endmodule


// Up/Down counter
module up_down_counter #(
    parameter int WIDTH = 8
) (
    input  logic             clk,
    input  logic             rst_n,
    input  logic             enable,
    input  logic             direction,  // 1=up, 0=down
    input  logic             load,
    input  logic [WIDTH-1:0] load_val,
    output logic [WIDTH-1:0] count
);
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            count <= '0;
        else if (load)
            count <= load_val;
        else if (enable) begin
            if (direction)
                count <= count + 1'b1;
            else
                count <= count - 1'b1;
        end
    end
endmodule


// Gray code counter (single-bit transitions, useful for CDC)
module gray_counter #(
    parameter int WIDTH = 4
) (
    input  logic             clk,
    input  logic             rst_n,
    input  logic             enable,
    output logic [WIDTH-1:0] gray_count,
    output logic [WIDTH-1:0] binary_count
);
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            binary_count <= '0;
        else if (enable)
            binary_count <= binary_count + 1'b1;
    end

    // Binary to Gray conversion: G = B ^ (B >> 1)
    assign gray_count = binary_count ^ (binary_count >> 1);
endmodule


// Ring counter (one-hot rotating pattern)
module ring_counter #(
    parameter int WIDTH = 8
) (
    input  logic             clk,
    input  logic             rst_n,
    input  logic             enable,
    output logic [WIDTH-1:0] ring
);
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            ring <= {{(WIDTH-1){1'b0}}, 1'b1};
        else if (enable)
            ring <= {ring[WIDTH-2:0], ring[WIDTH-1]};
    end
endmodule
