// SystemVerilog Port Declaration Styles
// Demonstrates ANSI vs non-ANSI port styles and port directions

// Style 1: ANSI port declaration (preferred, modern)
module ansi_ports (
    input  logic       clk,
    input  logic       rst_n,
    input  logic [7:0] a,
    input  logic [7:0] b,
    output logic [8:0] sum,
    output logic       carry
);
    assign {carry, sum[7:0]} = a + b;
    assign sum[8] = carry;
endmodule


// Style 2: Non-ANSI port declaration (legacy, still valid)
module non_ansi_ports (clk, rst_n, a, b, sum, carry);
    input        clk;
    input        rst_n;
    input  [7:0] a;
    input  [7:0] b;
    output [8:0] sum;
    output       carry;

    logic [8:0] sum;
    logic       carry;

    assign {carry, sum[7:0]} = a + b;
    assign sum[8] = carry;
endmodule


// Style 3: Using inout for bidirectional ports (e.g., I2C SDA)
module bidir_port (
    input  logic       clk,
    input  logic       rst_n,
    input  logic       drive_en,
    input  logic [7:0] data_out,
    output logic [7:0] data_in,
    inout  wire  [7:0] bidir_bus
);
    assign bidir_bus = drive_en ? data_out : 8'bz;
    assign data_in   = bidir_bus;
endmodule
