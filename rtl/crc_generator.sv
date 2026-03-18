// =============================================================================
// Parallel CRC Generator (CRC-32 / Ethernet)
// Demonstrates: XOR-based combinational logic, LFSR, parameterized CRC
// =============================================================================

module crc_generator #(
    parameter int DATA_WIDTH = 8,
    parameter int CRC_WIDTH  = 32,
    parameter logic [CRC_WIDTH-1:0] POLYNOMIAL = 32'h04C11DB7  // CRC-32/Ethernet
) (
    input  logic                  clk,
    input  logic                  rst_n,
    input  logic                  clear,
    input  logic                  valid,
    input  logic [DATA_WIDTH-1:0] data_in,
    output logic [CRC_WIDTH-1:0]  crc_out,
    output logic                  crc_valid
);

    logic [CRC_WIDTH-1:0] crc_reg;
    logic [CRC_WIDTH-1:0] crc_next;

    // Bit-serial CRC for one data bit (LFSR step)
    function automatic logic [CRC_WIDTH-1:0] crc_step(
        input logic [CRC_WIDTH-1:0] crc_in,
        input logic data_bit
    );
        logic feedback;
        feedback = crc_in[CRC_WIDTH-1] ^ data_bit;
        crc_step = {crc_in[CRC_WIDTH-2:0], 1'b0} ^ (feedback ? POLYNOMIAL : '0);
    endfunction

    // Parallel CRC: process all data bits in one cycle
    function automatic logic [CRC_WIDTH-1:0] crc_parallel(
        input logic [CRC_WIDTH-1:0]  crc_in,
        input logic [DATA_WIDTH-1:0] data
    );
        logic [CRC_WIDTH-1:0] crc_tmp;
        crc_tmp = crc_in;
        for (int i = DATA_WIDTH - 1; i >= 0; i--)
            crc_tmp = crc_step(crc_tmp, data[i]);
        return crc_tmp;
    endfunction

    assign crc_next = crc_parallel(crc_reg, data_in);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            crc_reg   <= '1;  // Standard init to all 1s
            crc_valid <= 1'b0;
        end else if (clear) begin
            crc_reg   <= '1;
            crc_valid <= 1'b0;
        end else if (valid) begin
            crc_reg   <= crc_next;
            crc_valid <= 1'b1;
        end
    end

    // Final CRC output is bitwise inverted (per Ethernet standard)
    assign crc_out = ~crc_reg;

endmodule
