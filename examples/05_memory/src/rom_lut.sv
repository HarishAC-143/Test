// ROM / Lookup Table
// Implements a sine-wave quarter-cycle LUT (0° to 90°) with 64 entries.
// Synthesis tools map this to distributed ROM or BRAM depending on size.

module rom_lut #(
    parameter ADDR_WIDTH = 6,
    parameter DATA_WIDTH = 8
)(
    input  logic                    clk,
    input  logic [ADDR_WIDTH-1:0]   addr,
    output logic [DATA_WIDTH-1:0]   data
);

    logic [DATA_WIDTH-1:0] rom [0:2**ADDR_WIDTH-1];

    // Quarter-sine lookup (8-bit unsigned, 0..255 representing 0..1.0)
    initial begin
        rom[0]  = 8'd0;   rom[1]  = 8'd6;   rom[2]  = 8'd13;  rom[3]  = 8'd19;
        rom[4]  = 8'd25;  rom[5]  = 8'd31;  rom[6]  = 8'd37;  rom[7]  = 8'd44;
        rom[8]  = 8'd50;  rom[9]  = 8'd56;  rom[10] = 8'd62;  rom[11] = 8'd68;
        rom[12] = 8'd74;  rom[13] = 8'd80;  rom[14] = 8'd86;  rom[15] = 8'd92;
        rom[16] = 8'd98;  rom[17] = 8'd103; rom[18] = 8'd109; rom[19] = 8'd115;
        rom[20] = 8'd120; rom[21] = 8'd126; rom[22] = 8'd131; rom[23] = 8'd136;
        rom[24] = 8'd142; rom[25] = 8'd147; rom[26] = 8'd152; rom[27] = 8'd157;
        rom[28] = 8'd162; rom[29] = 8'd167; rom[30] = 8'd171; rom[31] = 8'd176;
        rom[32] = 8'd181; rom[33] = 8'd185; rom[34] = 8'd189; rom[35] = 8'd193;
        rom[36] = 8'd197; rom[37] = 8'd201; rom[38] = 8'd205; rom[39] = 8'd209;
        rom[40] = 8'd212; rom[41] = 8'd216; rom[42] = 8'd219; rom[43] = 8'd222;
        rom[44] = 8'd225; rom[45] = 8'd228; rom[46] = 8'd231; rom[47] = 8'd234;
        rom[48] = 8'd236; rom[49] = 8'd238; rom[50] = 8'd241; rom[51] = 8'd243;
        rom[52] = 8'd244; rom[53] = 8'd246; rom[54] = 8'd248; rom[55] = 8'd249;
        rom[56] = 8'd251; rom[57] = 8'd252; rom[58] = 8'd253; rom[59] = 8'd254;
        rom[60] = 8'd254; rom[61] = 8'd255; rom[62] = 8'd255; rom[63] = 8'd255;
    end

    always_ff @(posedge clk) begin
        data <= rom[addr];
    end

endmodule
