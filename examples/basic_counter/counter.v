// Basic 8-bit synchronous counter with enable and load
// Demonstrates: Simple clocked design for basic SDC constraints

module counter #(
    parameter WIDTH = 8
)(
    input  wire              clk,
    input  wire              rst_n,
    input  wire              enable,
    input  wire              load,
    input  wire [WIDTH-1:0]  load_data,
    output reg  [WIDTH-1:0]  count,
    output wire              overflow
);

    assign overflow = (count == {WIDTH{1'b1}}) & enable;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count <= {WIDTH{1'b0}};
        end else if (load) begin
            count <= load_data;
        end else if (enable) begin
            count <= count + 1'b1;
        end
    end

endmodule
