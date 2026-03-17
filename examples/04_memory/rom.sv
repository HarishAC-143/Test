// Read-Only Memory with initialization from file

module rom #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 8,
    parameter INIT_FILE  = ""
)(
    input  logic                    clk,
    input  logic [ADDR_WIDTH-1:0]   addr,
    output logic [DATA_WIDTH-1:0]   data_out
);

    logic [DATA_WIDTH-1:0] mem [0:(1<<ADDR_WIDTH)-1];

    initial begin
        if (INIT_FILE != "")
            $readmemh(INIT_FILE, mem);
    end

    always_ff @(posedge clk) begin
        data_out <= mem[addr];
    end

endmodule


// Lookup Table ROM (combinational, no clock needed)
module lut_sine #(
    parameter DEPTH     = 256,
    parameter OUT_WIDTH = 8
)(
    input  logic [$clog2(DEPTH)-1:0] addr,
    output logic [OUT_WIDTH-1:0]     data_out
);

    logic [OUT_WIDTH-1:0] sine_table [0:DEPTH-1];

    initial begin
        for (int i = 0; i < DEPTH; i++) begin
            sine_table[i] = OUT_WIDTH'(
                $rtoi($floor(
                    (2.0**(OUT_WIDTH-1) - 1) *
                    $sin(2.0 * 3.14159265 * real'(i) / real'(DEPTH)) +
                    2.0**(OUT_WIDTH-1)
                ))
            );
        end
    end

    assign data_out = sine_table[addr];

endmodule
