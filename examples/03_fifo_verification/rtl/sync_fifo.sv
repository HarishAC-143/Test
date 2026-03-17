// Synchronous FIFO — Design Under Test
module sync_fifo #(
  parameter DATA_WIDTH = 8,
  parameter FIFO_DEPTH = 16,
  parameter ADDR_WIDTH = $clog2(FIFO_DEPTH)
)(
  input  logic                    clk,
  input  logic                    rst_n,

  // Write interface
  input  logic [DATA_WIDTH-1:0]   wr_data,
  input  logic                    wr_en,
  output logic                    full,

  // Read interface
  output logic [DATA_WIDTH-1:0]   rd_data,
  input  logic                    rd_en,
  output logic                    empty,

  // Status
  output logic [ADDR_WIDTH:0]     count
);

  logic [DATA_WIDTH-1:0] mem [0:FIFO_DEPTH-1];
  logic [ADDR_WIDTH:0]   wr_ptr;
  logic [ADDR_WIDTH:0]   rd_ptr;

  assign count = wr_ptr - rd_ptr;
  assign full  = (count == FIFO_DEPTH);
  assign empty = (count == 0);

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      wr_ptr  <= '0;
      rd_ptr  <= '0;
      rd_data <= '0;
    end else begin
      // Write logic
      if (wr_en && !full) begin
        mem[wr_ptr[ADDR_WIDTH-1:0]] <= wr_data;
        wr_ptr <= wr_ptr + 1;
      end

      // Read logic
      if (rd_en && !empty) begin
        rd_data <= mem[rd_ptr[ADDR_WIDTH-1:0]];
        rd_ptr  <= rd_ptr + 1;
      end
    end
  end

endmodule
