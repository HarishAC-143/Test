// Single-port RAM with optional byte-write enable.
// Synthesizes to Block RAM on most FPGA families.

module single_port_ram #(
    parameter int DATA_WIDTH = 32,
    parameter int ADDR_WIDTH = 10,
    parameter int NUM_BYTES  = DATA_WIDTH / 8
)(
    input  logic                  clk,
    input  logic                  en,         // chip enable
    input  logic [NUM_BYTES-1:0]  we,         // byte write enables
    input  logic [ADDR_WIDTH-1:0] addr,
    input  logic [DATA_WIDTH-1:0] din,
    output logic [DATA_WIDTH-1:0] dout
);

    localparam int DEPTH = 1 << ADDR_WIDTH;

    logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    always_ff @(posedge clk) begin
        if (en) begin
            for (int i = 0; i < NUM_BYTES; i++) begin
                if (we[i])
                    mem[addr][i*8 +: 8] <= din[i*8 +: 8];
            end
            dout <= mem[addr];  // READ_FIRST behavior
        end
    end

endmodule
