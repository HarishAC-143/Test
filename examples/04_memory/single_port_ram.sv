// Single-Port Synchronous RAM
// Read and write share the same address port

module single_port_ram #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 10
)(
    input  logic                    clk,
    input  logic                    we,
    input  logic [ADDR_WIDTH-1:0]   addr,
    input  logic [DATA_WIDTH-1:0]   data_in,
    output logic [DATA_WIDTH-1:0]   data_out
);

    logic [DATA_WIDTH-1:0] mem [0:(1<<ADDR_WIDTH)-1];

    always_ff @(posedge clk) begin
        if (we)
            mem[addr] <= data_in;
        data_out <= mem[addr];
    end

endmodule
