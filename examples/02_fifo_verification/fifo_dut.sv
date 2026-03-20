module fifo_dut #(
  parameter DATA_WIDTH = 8,
  parameter DEPTH      = 16,
  parameter ALMOST_FULL_THRESH  = DEPTH - 2,
  parameter ALMOST_EMPTY_THRESH = 2
)(
  input  logic                  clk,
  input  logic                  rst_n,
  // Write port
  input  logic                  wr_en,
  input  logic [DATA_WIDTH-1:0] wr_data,
  // Read port
  input  logic                  rd_en,
  output logic [DATA_WIDTH-1:0] rd_data,
  // Status
  output logic                  full,
  output logic                  empty,
  output logic                  almost_full,
  output logic                  almost_empty,
  output logic [$clog2(DEPTH):0] count,
  output logic                  overflow,
  output logic                  underflow
);

  localparam ADDR_WIDTH = $clog2(DEPTH);

  logic [DATA_WIDTH-1:0] mem [DEPTH];
  logic [ADDR_WIDTH:0] wr_ptr, rd_ptr;

  assign count = wr_ptr - rd_ptr;
  assign full  = (count == DEPTH);
  assign empty = (count == 0);
  assign almost_full  = (count >= ALMOST_FULL_THRESH);
  assign almost_empty = (count <= ALMOST_EMPTY_THRESH) && !empty;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      wr_ptr    <= '0;
      rd_ptr    <= '0;
      rd_data   <= '0;
      overflow  <= 1'b0;
      underflow <= 1'b0;
    end else begin
      overflow  <= 1'b0;
      underflow <= 1'b0;

      if (wr_en) begin
        if (!full) begin
          mem[wr_ptr[ADDR_WIDTH-1:0]] <= wr_data;
          wr_ptr <= wr_ptr + 1;
        end else begin
          overflow <= 1'b1;
        end
      end

      if (rd_en) begin
        if (!empty) begin
          rd_data <= mem[rd_ptr[ADDR_WIDTH-1:0]];
          rd_ptr  <= rd_ptr + 1;
        end else begin
          underflow <= 1'b1;
        end
      end
    end
  end

endmodule
