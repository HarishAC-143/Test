// Parameterized up/down counter with enable, load, and overflow detection.
// Supports both wrap-around and saturation modes.

module counter #(
    parameter int WIDTH    = 8,
    parameter bit SATURATE = 1'b0
)(
    input  logic             clk,
    input  logic             rst_n,
    input  logic             enable,
    input  logic             load,
    input  logic             up_down,    // 1 = count up, 0 = count down
    input  logic [WIDTH-1:0] load_val,
    output logic [WIDTH-1:0] count,
    output logic             overflow,
    output logic             underflow
);

    localparam logic [WIDTH-1:0] MAX_VAL = {WIDTH{1'b1}};
    localparam logic [WIDTH-1:0] MIN_VAL = {WIDTH{1'b0}};

    logic [WIDTH-1:0] count_next;
    logic             overflow_next;
    logic             underflow_next;

    always_comb begin
        count_next     = count;
        overflow_next  = 1'b0;
        underflow_next = 1'b0;

        if (load) begin
            count_next = load_val;
        end else if (enable) begin
            if (up_down) begin
                // Count up
                if (count == MAX_VAL) begin
                    overflow_next = 1'b1;
                    count_next    = SATURATE ? MAX_VAL : MIN_VAL;
                end else begin
                    count_next = count + 1'b1;
                end
            end else begin
                // Count down
                if (count == MIN_VAL) begin
                    underflow_next = 1'b1;
                    count_next     = SATURATE ? MIN_VAL : MAX_VAL;
                end else begin
                    count_next = count - 1'b1;
                end
            end
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count     <= MIN_VAL;
            overflow  <= 1'b0;
            underflow <= 1'b0;
        end else begin
            count     <= count_next;
            overflow  <= overflow_next;
            underflow <= underflow_next;
        end
    end

endmodule
