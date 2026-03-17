// Up Counter with enable and synchronous clear
module up_counter #(
    parameter WIDTH = 8
)(
    input  logic             clk,
    input  logic             rst_n,
    input  logic             enable,
    input  logic             clear,
    output logic [WIDTH-1:0] count,
    output logic             overflow
);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            count <= '0;
        else if (clear)
            count <= '0;
        else if (enable)
            count <= count + 1'b1;
    end

    assign overflow = enable & (&count);

endmodule


// Up/Down Counter with loadable value
module updown_counter #(
    parameter WIDTH = 8
)(
    input  logic             clk,
    input  logic             rst_n,
    input  logic             enable,
    input  logic             up_down,     // 1=up, 0=down
    input  logic             load,
    input  logic [WIDTH-1:0] load_val,
    output logic [WIDTH-1:0] count,
    output logic             terminal_count
);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            count <= '0;
        else if (load)
            count <= load_val;
        else if (enable) begin
            if (up_down)
                count <= count + 1'b1;
            else
                count <= count - 1'b1;
        end
    end

    assign terminal_count = enable & (up_down ? (&count) : ~(|count));

endmodule


// Modulo-N Counter (counts from 0 to N-1)
module mod_n_counter #(
    parameter N     = 10,
    parameter WIDTH = $clog2(N)
)(
    input  logic             clk,
    input  logic             rst_n,
    input  logic             enable,
    output logic [WIDTH-1:0] count,
    output logic             tick
);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            count <= '0;
        else if (enable) begin
            if (count == N - 1)
                count <= '0;
            else
                count <= count + 1'b1;
        end
    end

    assign tick = enable & (count == N - 1);

endmodule


// Gray Code Counter (only one bit changes per transition)
module gray_counter #(
    parameter WIDTH = 4
)(
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

    assign gray_count = binary_count ^ (binary_count >> 1);

endmodule
