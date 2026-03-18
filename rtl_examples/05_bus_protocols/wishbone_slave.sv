// =============================================================================
// Wishbone B4 Pipelined Slave Interface
// Implements a simple memory-mapped register bank.
// Supports single-cycle read and write with pipelined acknowledgment.
// =============================================================================

module wishbone_slave #(
    parameter ADDR_WIDTH = 8,
    parameter DATA_WIDTH = 32,
    parameter NUM_REGS   = 16,
    parameter SEL_WIDTH  = DATA_WIDTH / 8
) (
    input  logic                    wb_clk_i,
    input  logic                    wb_rst_i,

    // Wishbone signals
    input  logic                    wb_cyc_i,
    input  logic                    wb_stb_i,
    input  logic                    wb_we_i,
    input  logic [ADDR_WIDTH-1:0]   wb_adr_i,
    input  logic [DATA_WIDTH-1:0]   wb_dat_i,
    input  logic [SEL_WIDTH-1:0]    wb_sel_i,
    output logic [DATA_WIDTH-1:0]   wb_dat_o,
    output logic                    wb_ack_o,
    output logic                    wb_err_o
);

    localparam REG_ADDR_WIDTH = $clog2(NUM_REGS);

    logic [DATA_WIDTH-1:0] regs [NUM_REGS];
    logic valid_access;
    logic [REG_ADDR_WIDTH-1:0] reg_index;

    assign valid_access = wb_cyc_i && wb_stb_i;
    assign reg_index    = wb_adr_i[REG_ADDR_WIDTH+1:2];

    // Pipelined ACK — one cycle after STB
    always_ff @(posedge wb_clk_i) begin
        if (wb_rst_i) begin
            wb_ack_o <= 1'b0;
            wb_err_o <= 1'b0;
        end else begin
            wb_ack_o <= valid_access && !wb_ack_o;
            wb_err_o <= 1'b0;
        end
    end

    // Write
    always_ff @(posedge wb_clk_i) begin
        if (wb_rst_i) begin
            for (int i = 0; i < NUM_REGS; i++)
                regs[i] <= '0;
        end else if (valid_access && wb_we_i && !wb_ack_o) begin
            for (int b = 0; b < SEL_WIDTH; b++) begin
                if (wb_sel_i[b])
                    regs[reg_index][8*b +: 8] <= wb_dat_i[8*b +: 8];
            end
        end
    end

    // Read
    assign wb_dat_o = regs[reg_index];

endmodule
