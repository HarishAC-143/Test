// 4-to-1 Multiplexer using different modeling styles

// Style 1: Using case statement
module mux4to1_case #(
    parameter WIDTH = 8
)(
    input  logic [WIDTH-1:0] data_in [4],
    input  logic [1:0]       sel,
    output logic [WIDTH-1:0] data_out
);

    always_comb begin
        case (sel)
            2'b00:   data_out = data_in[0];
            2'b01:   data_out = data_in[1];
            2'b10:   data_out = data_in[2];
            2'b11:   data_out = data_in[3];
            default: data_out = '0;
        endcase
    end

endmodule

// Style 2: Using conditional (ternary) operator
module mux4to1_ternary #(
    parameter WIDTH = 8
)(
    input  logic [WIDTH-1:0] a, b, c, d,
    input  logic [1:0]       sel,
    output logic [WIDTH-1:0] y
);

    assign y = (sel == 2'b00) ? a :
               (sel == 2'b01) ? b :
               (sel == 2'b10) ? c : d;

endmodule

// Style 3: Using array indexing
module mux4to1_indexed #(
    parameter WIDTH = 8
)(
    input  logic [WIDTH-1:0] data_in [4],
    input  logic [1:0]       sel,
    output logic [WIDTH-1:0] data_out
);

    assign data_out = data_in[sel];

endmodule
