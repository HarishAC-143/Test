// Programmable clock divider.
// Generates a clock-enable pulse every DIVISOR cycles.
// Output is a single-cycle enable, NOT a gated clock (FPGA best practice).

module clock_divider #(
    parameter int MAX_DIVISOR = 256
)(
    input  logic                          clk,
    input  logic                          rst_n,
    input  logic [$clog2(MAX_DIVISOR)-1:0] divisor, // divide ratio (0 = every cycle)
    output logic                          tick       // single-cycle enable output
);

    logic [$clog2(MAX_DIVISOR)-1:0] count;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count <= '0;
            tick  <= 1'b0;
        end else if (count >= divisor) begin
            count <= '0;
            tick  <= 1'b1;
        end else begin
            count <= count + 1'b1;
            tick  <= 1'b0;
        end
    end

endmodule
