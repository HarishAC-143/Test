// Multiplexer implementations in SystemVerilog
// Demonstrates always_comb, case, ternary operator, and unique/priority

// 2:1 MUX using ternary operator
module mux_2to1 (
    input  logic       sel,
    input  logic [7:0] a,
    input  logic [7:0] b,
    output logic [7:0] y
);
    assign y = sel ? b : a;
endmodule


// 4:1 MUX using always_comb and case
module mux_4to1 (
    input  logic [1:0] sel,
    input  logic [7:0] a, b, c, d,
    output logic [7:0] y
);
    always_comb begin
        case (sel)
            2'b00:   y = a;
            2'b01:   y = b;
            2'b10:   y = c;
            2'b11:   y = d;
            default: y = '0;
        endcase
    end
endmodule


// 4:1 MUX using unique case (synthesis hint: all cases are mutually exclusive)
module mux_4to1_unique (
    input  logic [1:0] sel,
    input  logic [7:0] a, b, c, d,
    output logic [7:0] y
);
    always_comb begin
        unique case (sel)
            2'b00:   y = a;
            2'b01:   y = b;
            2'b10:   y = c;
            2'b11:   y = d;
        endcase
    end
endmodule


// Priority MUX using priority if
module priority_mux (
    input  logic [3:0] req,
    input  logic [7:0] d0, d1, d2, d3,
    output logic [7:0] y,
    output logic       valid
);
    always_comb begin
        valid = 1'b1;
        priority if (req[3]) begin
            y = d3;
        end else if (req[2]) begin
            y = d2;
        end else if (req[1]) begin
            y = d1;
        end else if (req[0]) begin
            y = d0;
        end else begin
            y     = '0;
            valid = 1'b0;
        end
    end
endmodule
