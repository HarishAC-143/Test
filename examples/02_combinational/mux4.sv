// ============================================================================
// 4:1 Multiplexer — Three Coding Styles
// ============================================================================
// Demonstrates three equivalent ways to implement a multiplexer:
// 1. Ternary chain (continuous assign)
// 2. always_comb with case
// 3. Indexed array
// ============================================================================

// Style 1: Ternary operator chain
module mux4_ternary #(
    parameter int WIDTH = 8
)(
    input  logic [1:0]       sel,
    input  logic [WIDTH-1:0] d0, d1, d2, d3,
    output logic [WIDTH-1:0] y
);
    assign y = (sel == 2'b00) ? d0 :
               (sel == 2'b01) ? d1 :
               (sel == 2'b10) ? d2 : d3;
endmodule

// Style 2: always_comb with unique case
module mux4_case #(
    parameter int WIDTH = 8
)(
    input  logic [1:0]       sel,
    input  logic [WIDTH-1:0] d0, d1, d2, d3,
    output logic [WIDTH-1:0] y
);
    always_comb begin
        unique case (sel)
            2'b00:   y = d0;
            2'b01:   y = d1;
            2'b10:   y = d2;
            2'b11:   y = d3;
            default: y = '0;
        endcase
    end
endmodule

// Style 3: Array indexing
module mux4_array #(
    parameter int WIDTH = 8
)(
    input  logic [1:0]       sel,
    input  logic [WIDTH-1:0] d [4],
    output logic [WIDTH-1:0] y
);
    assign y = d[sel];
endmodule
