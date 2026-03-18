// ----------------------------------------------------------------------------
// Parallel CRC Generator/Checker (CRC-32)
// Demonstrates: LFSR-based CRC, parallel computation using XOR matrix,
//               configurable polynomial, byte-at-a-time processing
// ----------------------------------------------------------------------------

module crc32_engine #(
    parameter int DATA_WIDTH = 8,
    parameter logic [31:0] POLYNOMIAL = 32'h04C11DB7,  // CRC-32 (Ethernet)
    parameter logic [31:0] INIT_VALUE = 32'hFFFFFFFF,
    parameter logic [31:0] XOR_OUT    = 32'hFFFFFFFF
)(
    input  logic                    clk,
    input  logic                    rst_n,
    input  logic                    init,       // Initialize CRC
    input  logic                    valid,      // Data valid
    input  logic [DATA_WIDTH-1:0]   data_in,
    output logic [31:0]             crc_out,
    output logic                    crc_valid
);

    logic [31:0] crc_reg;
    logic [31:0] crc_next;

    // Reflect input bits (LSB-first for standard CRC-32)
    function automatic logic [DATA_WIDTH-1:0] reflect_data(
        input logic [DATA_WIDTH-1:0] d
    );
        logic [DATA_WIDTH-1:0] reflected;
        for (int i = 0; i < DATA_WIDTH; i++)
            reflected[i] = d[DATA_WIDTH-1-i];
        return reflected;
    endfunction

    function automatic logic [31:0] reflect_crc(input logic [31:0] c);
        logic [31:0] reflected;
        for (int i = 0; i < 32; i++)
            reflected[i] = c[31-i];
        return reflected;
    endfunction

    // Compute CRC for one data word (serial bit processing, unrolled)
    function automatic logic [31:0] crc_step(
        input logic [31:0]          crc_in,
        input logic [DATA_WIDTH-1:0] data
    );
        logic [31:0] c;
        logic [DATA_WIDTH-1:0] d;
        c = crc_in;
        d = reflect_data(data);
        for (int i = 0; i < DATA_WIDTH; i++) begin
            if (c[31] ^ d[i])
                c = {c[30:0], 1'b0} ^ POLYNOMIAL;
            else
                c = {c[30:0], 1'b0};
        end
        return c;
    endfunction

    assign crc_next = crc_step(crc_reg, data_in);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            crc_reg   <= INIT_VALUE;
            crc_valid <= 1'b0;
        end else if (init) begin
            crc_reg   <= INIT_VALUE;
            crc_valid <= 1'b0;
        end else if (valid) begin
            crc_reg   <= crc_next;
            crc_valid <= 1'b1;
        end else begin
            crc_valid <= 1'b0;
        end
    end

    assign crc_out = reflect_crc(crc_reg) ^ XOR_OUT;

endmodule
