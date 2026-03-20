// Memory Models for FPGA
// FPGAs have dedicated Block RAM (BRAM) and Distributed RAM resources.
// The coding style determines which resource the synthesizer infers.

// ============================================================================
// Single-Port RAM (infers Block RAM on most FPGAs)
// ============================================================================
module single_port_ram #(
    parameter int DATA_WIDTH = 32,
    parameter int ADDR_WIDTH = 10,
    parameter int DEPTH      = 2**ADDR_WIDTH
) (
    input  logic                  clk,
    input  logic                  we,
    input  logic [ADDR_WIDTH-1:0] addr,
    input  logic [DATA_WIDTH-1:0] din,
    output logic [DATA_WIDTH-1:0] dout
);
    logic [DATA_WIDTH-1:0] mem [DEPTH];

    always_ff @(posedge clk) begin
        if (we)
            mem[addr] <= din;
        dout <= mem[addr];  // Read-first mode
    end
endmodule


// ============================================================================
// Simple Dual-Port RAM (one read port, one write port)
// ============================================================================
module simple_dual_port_ram #(
    parameter int DATA_WIDTH = 32,
    parameter int ADDR_WIDTH = 10,
    parameter int DEPTH      = 2**ADDR_WIDTH
) (
    input  logic                  clk,

    // Write port
    input  logic                  we,
    input  logic [ADDR_WIDTH-1:0] wr_addr,
    input  logic [DATA_WIDTH-1:0] wr_data,

    // Read port
    input  logic [ADDR_WIDTH-1:0] rd_addr,
    output logic [DATA_WIDTH-1:0] rd_data
);
    logic [DATA_WIDTH-1:0] mem [DEPTH];

    always_ff @(posedge clk) begin
        if (we)
            mem[wr_addr] <= wr_data;
        rd_data <= mem[rd_addr];
    end
endmodule


// ============================================================================
// True Dual-Port RAM (both ports can read and write)
// ============================================================================
module true_dual_port_ram #(
    parameter int DATA_WIDTH = 32,
    parameter int ADDR_WIDTH = 10,
    parameter int DEPTH      = 2**ADDR_WIDTH
) (
    // Port A
    input  logic                  clk_a,
    input  logic                  we_a,
    input  logic [ADDR_WIDTH-1:0] addr_a,
    input  logic [DATA_WIDTH-1:0] din_a,
    output logic [DATA_WIDTH-1:0] dout_a,

    // Port B
    input  logic                  clk_b,
    input  logic                  we_b,
    input  logic [ADDR_WIDTH-1:0] addr_b,
    input  logic [DATA_WIDTH-1:0] din_b,
    output logic [DATA_WIDTH-1:0] dout_b
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


// ============================================================================
// ROM (Read-Only Memory) with initialization
// ============================================================================
module rom_lookup #(
    parameter int DATA_WIDTH = 16,
    parameter int ADDR_WIDTH = 8,
    parameter int DEPTH      = 2**ADDR_WIDTH
) (
    input  logic                  clk,
    input  logic [ADDR_WIDTH-1:0] addr,
    output logic [DATA_WIDTH-1:0] dout
);
    logic [DATA_WIDTH-1:0] mem [DEPTH];

    // Initialize from file or inline
    initial begin
        // Option 1: Load from hex file
        // $readmemh("rom_data.hex", mem);

        // Option 2: Sine lookup table (256 entries, 16-bit)
        for (int i = 0; i < DEPTH; i++) begin
            mem[i] = 16'(32767.0 * $sin(2.0 * 3.14159265 * real'(i) / real'(DEPTH)));
        end
    end

    always_ff @(posedge clk) begin
        dout <= mem[addr];
    end
endmodule


// ============================================================================
// RAM with byte-enable writes (common for processor data memory)
// ============================================================================
module ram_byte_enable #(
    parameter int ADDR_WIDTH = 10,
    parameter int DEPTH      = 2**ADDR_WIDTH
) (
    input  logic              clk,
    input  logic [3:0]        byte_en,
    input  logic              we,
    input  logic [ADDR_WIDTH-1:0] addr,
    input  logic [31:0]       din,
    output logic [31:0]       dout
);
    logic [31:0] mem [DEPTH];

    always_ff @(posedge clk) begin
        if (we) begin
            if (byte_en[0]) mem[addr][ 7: 0] <= din[ 7: 0];
            if (byte_en[1]) mem[addr][15: 8] <= din[15: 8];
            if (byte_en[2]) mem[addr][23:16] <= din[23:16];
            if (byte_en[3]) mem[addr][31:24] <= din[31:24];
        end
        dout <= mem[addr];
    end
endmodule
