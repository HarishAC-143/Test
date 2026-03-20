// True Dual-Port RAM
// Both ports can read and write independently, supporting different clocks.
// Infers true dual-port BRAM on Xilinx and Intel FPGAs.
// Simultaneous write to the same address from both ports is undefined.

module dual_port_ram #(
    parameter ADDR_WIDTH = 10,
    parameter DATA_WIDTH = 32
)(
    // Port A
    input  logic                    clk_a,
    input  logic                    we_a,
    input  logic [ADDR_WIDTH-1:0]   addr_a,
    input  logic [DATA_WIDTH-1:0]   wdata_a,
    output logic [DATA_WIDTH-1:0]   rdata_a,
    // Port B
    input  logic                    clk_b,
    input  logic                    we_b,
    input  logic [ADDR_WIDTH-1:0]   addr_b,
    input  logic [DATA_WIDTH-1:0]   wdata_b,
    output logic [DATA_WIDTH-1:0]   rdata_b
);

    logic [DATA_WIDTH-1:0] mem [0:2**ADDR_WIDTH-1];

    // Port A
    always_ff @(posedge clk_a) begin
        if (we_a)
            mem[addr_a] <= wdata_a;
        rdata_a <= mem[addr_a];
    end

    // Port B
    always_ff @(posedge clk_b) begin
        if (we_b)
            mem[addr_b] <= wdata_b;
        rdata_b <= mem[addr_b];
    end

endmodule
