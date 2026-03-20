// Synchronous FIFO DUT
module fifo_dut #(
  parameter DATA_WIDTH = 8,
  parameter DEPTH      = 16
)(
  input  logic                    clk,
  input  logic                    rst_n,
  input  logic                    wr_en,
  input  logic                    rd_en,
  input  logic [DATA_WIDTH-1:0]   wr_data,
  output logic [DATA_WIDTH-1:0]   rd_data,
  output logic                    full,
  output logic                    empty,
  output logic [$clog2(DEPTH):0]  count
);

  localparam ADDR_WIDTH = $clog2(DEPTH);

  logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];
  logic [ADDR_WIDTH:0]   wr_ptr, rd_ptr;

  assign full  = (count == DEPTH);
  assign empty = (count == 0);

  // Write pointer
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      wr_ptr <= 0;
    else if (wr_en && !full)
      wr_ptr <= wr_ptr + 1;
  end

  // Read pointer
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      rd_ptr <= 0;
    else if (rd_en && !empty)
      rd_ptr <= rd_ptr + 1;
  end

  // Count tracker
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      count <= 0;
    else begin
      case ({wr_en && !full, rd_en && !empty})
        2'b10:   count <= count + 1;
        2'b01:   count <= count - 1;
        default: count <= count;
      endcase
    end
  end

  // Memory write
  always_ff @(posedge clk) begin
    if (wr_en && !full)
      mem[wr_ptr[ADDR_WIDTH-1:0]] <= wr_data;
  end

  // Memory read
  assign rd_data = mem[rd_ptr[ADDR_WIDTH-1:0]];

endmodule
