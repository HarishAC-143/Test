// =============================================================================
// True Dual-Port RAM
// Both ports can independently read and write.
// Parameterized data width and depth.
// =============================================================================

module dual_port_ram #(
    parameter DATA_WIDTH = 32,
    parameter DEPTH      = 1024,
    parameter ADDR_WIDTH = $clog2(DEPTH)
) (
    // Port A
    input  logic                    clk_a,
    input  logic                    we_a,
    input  logic [ADDR_WIDTH-1:0]   addr_a,
    input  logic [DATA_WIDTH-1:0]   din_a,
    output logic [DATA_WIDTH-1:0]   dout_a,

    // Port B
    input  logic                    clk_b,
    input  logic                    we_b,
    input  logic [ADDR_WIDTH-1:0]   addr_b,
    input  logic [DATA_WIDTH-1:0]   din_b,
    output logic [DATA_WIDTH-1:0]   dout_b
);

    logic [DATA_WIDTH-1:0] mem [DEPTH];

    // Port A
    always_ff @(posedge clk_a) begin
        if (we_a)
            mem[addr_a] <= din_a;
        dout_a <= mem[addr_a];
    end

    // Port B
    always_ff @(posedge clk_b) begin
        if (we_b)
            mem[addr_b] <= din_b;
        dout_b <= mem[addr_b];
    end

endmodule
