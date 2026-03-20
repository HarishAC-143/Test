// ============================================================================
// Configurable Up/Down Counter
// ============================================================================
// Features: enable, synchronous load, configurable max count, direction
// control, terminal count output. Demonstrates best practices for
// sequential logic with parameterization.
// ============================================================================

module counter #(
    parameter int WIDTH     = 8,
    parameter int MAX_COUNT = (2**WIDTH) - 1
)(
    input  logic             clk,
    input  logic             rst_n,
    input  logic             en,
    input  logic             up_down,  // 1=up, 0=down
    input  logic             load,
    input  logic [WIDTH-1:0] load_val,
    output logic [WIDTH-1:0] count,
    output logic             tc,       // terminal count
    output logic             zero
);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            count <= '0;
        else if (load)
            count <= load_val;
        else if (en) begin
            if (up_down) begin
                if (count == MAX_COUNT[WIDTH-1:0])
                    count <= '0;
                else
                    count <= count + 1'b1;
            end else begin
                if (count == '0)
                    count <= MAX_COUNT[WIDTH-1:0];
                else
                    count <= count - 1'b1;
            end
        end
    end

    assign tc   = en && up_down && (count == MAX_COUNT[WIDTH-1:0]);
    assign zero = en && !up_down && (count == '0);

endmodule
