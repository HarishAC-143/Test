// Configurable up/down counter with synchronous load and enable.

module counter #(
    parameter int WIDTH     = 8,
    parameter int MAX_COUNT = (1 << WIDTH) - 1
)(
    input  logic             clk,
    input  logic             rst_n,
    input  logic             enable,
    input  logic             up_down,    // 1 = count up, 0 = count down
    input  logic             load,
    input  logic [WIDTH-1:0] load_val,
    output logic [WIDTH-1:0] count,
    output logic             wrap        // pulses when counter wraps
);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count <= '0;
            wrap  <= 1'b0;
        end else if (load) begin
            count <= load_val;
            wrap  <= 1'b0;
        end else if (enable) begin
            if (up_down) begin
                if (count == MAX_COUNT[WIDTH-1:0]) begin
                    count <= '0;
                    wrap  <= 1'b1;
                end else begin
                    count <= count + 1'b1;
                    wrap  <= 1'b0;
                end
            end else begin
                if (count == '0) begin
                    count <= MAX_COUNT[WIDTH-1:0];
                    wrap  <= 1'b1;
                end else begin
                    count <= count - 1'b1;
                    wrap  <= 1'b0;
                end
            end
        end else begin
            wrap <= 1'b0;
        end
    end

endmodule
