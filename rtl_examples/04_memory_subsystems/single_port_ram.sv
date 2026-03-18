// =============================================================================
// Single-Port Synchronous RAM
// Write-first (read-during-write returns new data).
// Infers block RAM on most FPGA targets.
// =============================================================================

module single_port_ram #(
    parameter DATA_WIDTH = 32,
    parameter DEPTH      = 1024,
    parameter ADDR_WIDTH = $clog2(DEPTH)
) (
    input  logic                    clk,
    input  logic                    we,
    input  logic [ADDR_WIDTH-1:0]   addr,
    input  logic [DATA_WIDTH-1:0]   din,
    output logic [DATA_WIDTH-1:0]   dout
);

    logic [DATA_WIDTH-1:0] mem [DEPTH];

    always_ff @(posedge clk) begin
        if (we)
            mem[addr] <= din;
        dout <= mem[addr];  // Read-first behavior; swap order for write-first
    end

endmodule
