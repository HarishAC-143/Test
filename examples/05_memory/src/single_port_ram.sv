// Single-Port RAM
// Infers block RAM (BRAM) on most FPGA architectures.
// Read-after-write behavior: read returns the OLD data (read-first mode).

module single_port_ram #(
    parameter ADDR_WIDTH = 10,
    parameter DATA_WIDTH = 32
)(
    input  logic                    clk,
    input  logic                    we,
    input  logic [ADDR_WIDTH-1:0]   addr,
    input  logic [DATA_WIDTH-1:0]   wdata,
    output logic [DATA_WIDTH-1:0]   rdata
);

    logic [DATA_WIDTH-1:0] mem [0:2**ADDR_WIDTH-1];

    always_ff @(posedge clk) begin
        if (we)
            mem[addr] <= wdata;
        rdata <= mem[addr];
    end

endmodule
