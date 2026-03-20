// Configurable Up/Down Counter
// Features: parameterized width, load, enable, direction control, overflow/underflow.

module counter #(
    parameter WIDTH     = 8,
    parameter MAX_COUNT = (2**WIDTH) - 1
)(
    input  logic             clk,
    input  logic             rst_n,
    input  logic             enable,
    input  logic             up_down,     // 1 = count up, 0 = count down
    input  logic             load,
    input  logic [WIDTH-1:0] load_val,
    output logic [WIDTH-1:0] count,
    output logic             overflow,
    output logic             underflow
);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count     <= '0;
            overflow  <= 1'b0;
            underflow <= 1'b0;
        end else if (load) begin
            count     <= load_val;
            overflow  <= 1'b0;
            underflow <= 1'b0;
        end else if (enable) begin
            if (up_down) begin
                // Count up
                if (count == MAX_COUNT[WIDTH-1:0]) begin
                    count    <= '0;
                    overflow <= 1'b1;
                end else begin
                    count    <= count + 1'b1;
                    overflow <= 1'b0;
                end
                underflow <= 1'b0;
            end else begin
                // Count down
                if (count == '0) begin
                    count     <= MAX_COUNT[WIDTH-1:0];
                    underflow <= 1'b1;
                end else begin
                    count     <= count - 1'b1;
                    underflow <= 1'b0;
                end
                overflow <= 1'b0;
            end
        end else begin
            overflow  <= 1'b0;
            underflow <= 1'b0;
        end
    end

endmodule
