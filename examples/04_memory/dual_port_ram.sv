// True Dual-Port RAM
// Two independent read/write ports, each with its own clock domain

module dual_port_ram #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 10
)(
    // Port A
    input  logic                    clk_a,
    input  logic                    we_a,
    input  logic [ADDR_WIDTH-1:0]   addr_a,
    input  logic [DATA_WIDTH-1:0]   data_in_a,
    output logic [DATA_WIDTH-1:0]   data_out_a,

    // Port B
    input  logic                    clk_b,
    input  logic                    we_b,
    input  logic [ADDR_WIDTH-1:0]   addr_b,
    input  logic [DATA_WIDTH-1:0]   data_in_b,
    output logic [DATA_WIDTH-1:0]   data_out_b
);

    logic [DATA_WIDTH-1:0] mem [0:(1<<ADDR_WIDTH)-1];

    // Port A
    always_ff @(posedge clk_a) begin
        if (we_a)
            mem[addr_a] <= data_in_a;
        data_out_a <= mem[addr_a];
    end

    // Port B
    always_ff @(posedge clk_b) begin
        if (we_b)
            mem[addr_b] <= data_in_b;
        data_out_b <= mem[addr_b];
    end

endmodule
