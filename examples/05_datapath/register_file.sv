// Register File with 2 read ports and 1 write port
// Commonly found in processor datapaths

module register_file #(
    parameter DATA_WIDTH  = 32,
    parameter NUM_REGS    = 32,
    parameter ADDR_WIDTH  = $clog2(NUM_REGS)
)(
    input  logic                   clk,
    input  logic                   rst_n,

    // Write port
    input  logic                   wr_en,
    input  logic [ADDR_WIDTH-1:0]  wr_addr,
    input  logic [DATA_WIDTH-1:0]  wr_data,

    // Read port A
    input  logic [ADDR_WIDTH-1:0]  rd_addr_a,
    output logic [DATA_WIDTH-1:0]  rd_data_a,

    // Read port B
    input  logic [ADDR_WIDTH-1:0]  rd_addr_b,
    output logic [DATA_WIDTH-1:0]  rd_data_b
);

    logic [DATA_WIDTH-1:0] regs [0:NUM_REGS-1];

    // Write (synchronous)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < NUM_REGS; i++)
                regs[i] <= '0;
        end else if (wr_en && wr_addr != '0) begin
            regs[wr_addr] <= wr_data;
        end
    end

    // Read (combinational with write-forwarding)
    assign rd_data_a = (rd_addr_a == '0) ? '0 :
                       (wr_en && wr_addr == rd_addr_a) ? wr_data :
                       regs[rd_addr_a];

    assign rd_data_b = (rd_addr_b == '0) ? '0 :
                       (wr_en && wr_addr == rd_addr_b) ? wr_data :
                       regs[rd_addr_b];

endmodule
