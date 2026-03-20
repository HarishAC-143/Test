// ============================================================================
// Single-Port SRAM Controller
// ============================================================================
// Demonstrates Block RAM inference patterns for FPGA synthesis tools.
// Key rules for Block RAM inference:
//   1. Use synchronous reads (register the output)
//   2. Do NOT reset the memory array
//   3. Depth ≥ 256 entries (tool-dependent threshold)
//   4. Address width must match $clog2(depth)
//
// This module also implements a simple request/acknowledge handshake.
// ============================================================================

module sram_controller #(
    parameter int ADDR_WIDTH = 10,
    parameter int DATA_WIDTH = 32
)(
    input  logic                   clk,
    input  logic                   rst_n,
    input  logic                   req,
    input  logic                   wr_en,
    input  logic [ADDR_WIDTH-1:0]  addr,
    input  logic [DATA_WIDTH-1:0]  wr_data,
    output logic [DATA_WIDTH-1:0]  rd_data,
    output logic                   ack
);

    localparam int DEPTH = 2**ADDR_WIDTH;

    // Block RAM inference: no reset on this array
    logic [DATA_WIDTH-1:0] mem [DEPTH];

    // Write port
    always_ff @(posedge clk) begin
        if (req && wr_en)
            mem[addr] <= wr_data;
    end

    // Read port — registered output (read-first behavior)
    always_ff @(posedge clk) begin
        if (req && !wr_en)
            rd_data <= mem[addr];
    end

    // Acknowledge: 1-cycle latency
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            ack <= 1'b0;
        else
            ack <= req;
    end

endmodule


// ============================================================================
// True Dual-Port RAM
// ============================================================================
// Two independent ports, each with its own clock, address, and data.
// Both ports can read or write independently.
// ============================================================================

module true_dual_port_ram #(
    parameter int ADDR_WIDTH = 10,
    parameter int DATA_WIDTH = 32
)(
    // Port A
    input  logic                   clk_a,
    input  logic                   en_a,
    input  logic                   we_a,
    input  logic [ADDR_WIDTH-1:0]  addr_a,
    input  logic [DATA_WIDTH-1:0]  din_a,
    output logic [DATA_WIDTH-1:0]  dout_a,

    // Port B
    input  logic                   clk_b,
    input  logic                   en_b,
    input  logic                   we_b,
    input  logic [ADDR_WIDTH-1:0]  addr_b,
    input  logic [DATA_WIDTH-1:0]  din_b,
    output logic [DATA_WIDTH-1:0]  dout_b
);

    localparam int DEPTH = 2**ADDR_WIDTH;

    logic [DATA_WIDTH-1:0] mem [DEPTH];

    // Port A
    always_ff @(posedge clk_a) begin
        if (en_a) begin
            if (we_a)
                mem[addr_a] <= din_a;
            dout_a <= mem[addr_a];
        end
    end

    // Port B
    always_ff @(posedge clk_b) begin
        if (en_b) begin
            if (we_b)
                mem[addr_b] <= din_b;
            dout_b <= mem[addr_b];
        end
    end

endmodule
