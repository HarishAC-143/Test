// ROM with compile-time initialization.
// Can be initialized via parameter or $readmemh from a file.
// Synthesis tools infer this as distributed ROM or Block ROM depending on size.

module rom_lookup #(
    parameter int DATA_WIDTH = 8,
    parameter int ADDR_WIDTH = 8,
    parameter string INIT_FILE = ""   // optional hex file for initialization
)(
    input  logic                  clk,
    input  logic [ADDR_WIDTH-1:0] addr,
    output logic [DATA_WIDTH-1:0] data
);

    localparam int DEPTH = 1 << ADDR_WIDTH;

    logic [DATA_WIDTH-1:0] rom [0:DEPTH-1];

    // Initialize ROM contents
    initial begin
        if (INIT_FILE != "") begin
            $readmemh(INIT_FILE, rom);
        end else begin
            // Default: sine lookup table (quarter wave, 256 entries, 8-bit)
            for (int i = 0; i < DEPTH; i++) begin
                rom[i] = DATA_WIDTH'(128 + int'(127.0 * $sin(2.0 * 3.14159265 * real'(i) / real'(DEPTH))));
            end
        end
    end

    // Synchronous read (infers BRAM)
    always_ff @(posedge clk) begin
        data <= rom[addr];
    end

endmodule
