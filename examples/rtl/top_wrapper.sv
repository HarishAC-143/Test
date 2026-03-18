// Top-level wrapper that instantiates counter, FIFO, and ALU modules.
// Adds I/O registers for timing closure — a common FPGA best practice.

module top_wrapper #(
    parameter int COUNTER_WIDTH = 8,
    parameter int FIFO_WIDTH    = 8,
    parameter int FIFO_DEPTH    = 16,
    parameter int ALU_WIDTH     = 16
)(
    input  logic                      clk,
    input  logic                      rst_n,

    // Counter interface
    input  logic                      cnt_enable,
    input  logic                      cnt_load,
    input  logic                      cnt_up_down,
    input  logic [COUNTER_WIDTH-1:0]  cnt_load_val,
    output logic [COUNTER_WIDTH-1:0]  cnt_value,
    output logic                      cnt_overflow,
    output logic                      cnt_underflow,

    // FIFO interface
    input  logic                      fifo_wr_en,
    input  logic                      fifo_rd_en,
    input  logic [FIFO_WIDTH-1:0]     fifo_wr_data,
    output logic [FIFO_WIDTH-1:0]     fifo_rd_data,
    output logic                      fifo_full,
    output logic                      fifo_empty,

    // ALU interface
    input  logic [ALU_WIDTH-1:0]      alu_a,
    input  logic [ALU_WIDTH-1:0]      alu_b,
    input  logic [3:0]                alu_op,
    output logic [ALU_WIDTH-1:0]      alu_result,
    output logic                      alu_zero,
    output logic                      alu_carry,
    output logic                      alu_overflow
);

    // ---------------------------------------------------------------
    // Input registers (improve input timing)
    // ---------------------------------------------------------------
    logic                      cnt_enable_r,  cnt_load_r, cnt_up_down_r;
    logic [COUNTER_WIDTH-1:0]  cnt_load_val_r;
    logic                      fifo_wr_en_r,  fifo_rd_en_r;
    logic [FIFO_WIDTH-1:0]     fifo_wr_data_r;
    logic [ALU_WIDTH-1:0]      alu_a_r, alu_b_r;
    logic [3:0]                alu_op_r;

    always_ff @(posedge clk) begin
        cnt_enable_r   <= cnt_enable;
        cnt_load_r     <= cnt_load;
        cnt_up_down_r  <= cnt_up_down;
        cnt_load_val_r <= cnt_load_val;
        fifo_wr_en_r   <= fifo_wr_en;
        fifo_rd_en_r   <= fifo_rd_en;
        fifo_wr_data_r <= fifo_wr_data;
        alu_a_r        <= alu_a;
        alu_b_r        <= alu_b;
        alu_op_r       <= alu_op;
    end

    // ---------------------------------------------------------------
    // Counter instance
    // ---------------------------------------------------------------
    logic [COUNTER_WIDTH-1:0] cnt_value_i;
    logic                     cnt_overflow_i, cnt_underflow_i;

    counter #(
        .WIDTH    (COUNTER_WIDTH),
        .SATURATE (1'b0)
    ) u_counter (
        .clk       (clk),
        .rst_n     (rst_n),
        .enable    (cnt_enable_r),
        .load      (cnt_load_r),
        .up_down   (cnt_up_down_r),
        .load_val  (cnt_load_val_r),
        .count     (cnt_value_i),
        .overflow  (cnt_overflow_i),
        .underflow (cnt_underflow_i)
    );

    // ---------------------------------------------------------------
    // FIFO instance
    // ---------------------------------------------------------------
    logic [FIFO_WIDTH-1:0] fifo_rd_data_i;
    logic                  fifo_full_i, fifo_empty_i;

    fifo_sync #(
        .DATA_WIDTH (FIFO_WIDTH),
        .DEPTH      (FIFO_DEPTH)
    ) u_fifo (
        .clk          (clk),
        .rst_n        (rst_n),
        .wr_en        (fifo_wr_en_r),
        .rd_en        (fifo_rd_en_r),
        .wr_data      (fifo_wr_data_r),
        .rd_data      (fifo_rd_data_i),
        .full         (fifo_full_i),
        .empty        (fifo_empty_i),
        .almost_full  (),
        .almost_empty (),
        .count        ()
    );

    // ---------------------------------------------------------------
    // ALU instance
    // ---------------------------------------------------------------
    logic [ALU_WIDTH-1:0] alu_result_i;
    logic                 alu_zero_i, alu_carry_i, alu_overflow_i;

    alu #(
        .WIDTH (ALU_WIDTH)
    ) u_alu (
        .operand_a     (alu_a_r),
        .operand_b     (alu_b_r),
        .operation     (alu_op_r),
        .result        (alu_result_i),
        .zero_flag     (alu_zero_i),
        .carry_flag    (alu_carry_i),
        .overflow_flag (alu_overflow_i)
    );

    // ---------------------------------------------------------------
    // Output registers (improve output timing)
    // ---------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt_value     <= '0;
            cnt_overflow  <= 1'b0;
            cnt_underflow <= 1'b0;
            fifo_rd_data  <= '0;
            fifo_full     <= 1'b0;
            fifo_empty    <= 1'b1;
            alu_result    <= '0;
            alu_zero      <= 1'b0;
            alu_carry     <= 1'b0;
            alu_overflow  <= 1'b0;
        end else begin
            cnt_value     <= cnt_value_i;
            cnt_overflow  <= cnt_overflow_i;
            cnt_underflow <= cnt_underflow_i;
            fifo_rd_data  <= fifo_rd_data_i;
            fifo_full     <= fifo_full_i;
            fifo_empty    <= fifo_empty_i;
            alu_result    <= alu_result_i;
            alu_zero      <= alu_zero_i;
            alu_carry     <= alu_carry_i;
            alu_overflow  <= alu_overflow_i;
        end
    end

endmodule
