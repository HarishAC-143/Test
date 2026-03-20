// Simple APB Slave Memory DUT
// 256-word memory with APB interface
module apb_slave_dut (
  input  logic        pclk,
  input  logic        preset_n,
  input  logic [31:0] paddr,
  input  logic        psel,
  input  logic        penable,
  input  logic        pwrite,
  input  logic [31:0] pwdata,
  output logic [31:0] prdata,
  output logic        pready,
  output logic        pslverr
);

  logic [31:0] mem [0:255];

  typedef enum logic [1:0] {
    IDLE   = 2'b00,
    SETUP  = 2'b01,
    ACCESS = 2'b10
  } state_t;

  state_t state, next_state;

  always_ff @(posedge pclk or negedge preset_n) begin
    if (!preset_n)
      state <= IDLE;
    else
      state <= next_state;
  end

  always_comb begin
    next_state = state;
    case (state)
      IDLE:    if (psel && !penable) next_state = SETUP;
      SETUP:   if (psel && penable)  next_state = ACCESS;
      ACCESS:  next_state = IDLE;
      default: next_state = IDLE;
    endcase
  end

  assign pready  = (state == ACCESS);
  assign pslverr = (state == ACCESS) && (paddr[31:10] != 0);

  always_ff @(posedge pclk) begin
    if (state == ACCESS && pwrite && !pslverr)
      mem[paddr[9:2]] <= pwdata;
  end

  always_ff @(posedge pclk) begin
    if (state == ACCESS && !pwrite && !pslverr)
      prdata <= mem[paddr[9:2]];
    else
      prdata <= 32'h0;
  end

endmodule
