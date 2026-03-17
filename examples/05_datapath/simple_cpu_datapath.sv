// Simple CPU Datapath
// Demonstrates how ALU, register file, and MUXes connect in a processor

module simple_cpu_datapath #(
    parameter DATA_WIDTH = 32
)(
    input  logic                    clk,
    input  logic                    rst_n,

    // Control signals (from control unit)
    input  logic [3:0]              alu_op,
    input  logic                    reg_write,
    input  logic                    alu_src,      // 0=reg, 1=immediate
    input  logic                    mem_to_reg,   // 0=ALU result, 1=memory data

    // Instruction fields
    input  logic [4:0]              rs1,
    input  logic [4:0]              rs2,
    input  logic [4:0]              rd,
    input  logic [DATA_WIDTH-1:0]   immediate,

    // Memory interface
    input  logic [DATA_WIDTH-1:0]   mem_read_data,
    output logic [DATA_WIDTH-1:0]   mem_addr,

    // Status
    output logic                    zero_flag
);

    logic [DATA_WIDTH-1:0] rd_data_a, rd_data_b;
    logic [DATA_WIDTH-1:0] alu_input_b;
    logic [DATA_WIDTH-1:0] alu_result;
    logic [DATA_WIDTH-1:0] write_back_data;

    // Register File
    register_file #(
        .DATA_WIDTH(DATA_WIDTH),
        .NUM_REGS(32)
    ) regfile (
        .clk       (clk),
        .rst_n     (rst_n),
        .wr_en     (reg_write),
        .wr_addr   (rd),
        .wr_data   (write_back_data),
        .rd_addr_a (rs1),
        .rd_data_a (rd_data_a),
        .rd_addr_b (rs2),
        .rd_data_b (rd_data_b)
    );

    // ALU source MUX
    assign alu_input_b = alu_src ? immediate : rd_data_b;

    // ALU
    logic carry_unused, overflow_unused;
    alu #(.WIDTH(DATA_WIDTH)) main_alu (
        .operand_a (rd_data_a),
        .operand_b (alu_input_b),
        .alu_op    (alu_op),
        .result    (alu_result),
        .zero      (zero_flag),
        .carry     (carry_unused),
        .overflow  (overflow_unused)
    );

    // Write-back MUX
    assign write_back_data = mem_to_reg ? mem_read_data : alu_result;

    // Memory address comes from ALU result
    assign mem_addr = alu_result;

endmodule
