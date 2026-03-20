// APB3-compliant slave memory (256 bytes / 64 words)
module apb_slave_dut #(
  parameter ADDR_WIDTH = 8,
  parameter DATA_WIDTH = 32,
  parameter MEM_DEPTH  = 64
)(
  input  logic                    pclk,
  input  logic                    preset_n,
  input  logic                    psel,
  input  logic                    penable,
  input  logic                    pwrite,
  input  logic [ADDR_WIDTH-1:0]   paddr,
  input  logic [DATA_WIDTH-1:0]   pwdata,
  input  logic [DATA_WIDTH/8-1:0] pstrb,
  output logic [DATA_WIDTH-1:0]   prdata,
  output logic                    pready,
  output logic                    pslverr
);

  logic [DATA_WIDTH-1:0] mem [MEM_DEPTH];
  logic [1:0] wait_counter;

  wire [$clog2(MEM_DEPTH)-1:0] word_addr = paddr[ADDR_WIDTH-1:2];
  wire addr_valid = (word_addr < MEM_DEPTH);

  typedef enum logic [1:0] {
    IDLE   = 2'b00,
    SETUP  = 2'b01,
    ACCESS = 2'b10
  } state_t;

  state_t state;

  always_ff @(posedge pclk or negedge preset_n) begin
    if (!preset_n) begin
      state        <= IDLE;
      prdata       <= '0;
      pready       <= 1'b1;
      pslverr      <= 1'b0;
      wait_counter <= '0;
      foreach (mem[i]) mem[i] <= '0;
    end else begin
      pslverr <= 1'b0;

      case (state)
        IDLE: begin
          pready <= 1'b1;
          if (psel && !penable)
            state <= SETUP;
        end

        SETUP: begin
          if (psel && penable) begin
            state <= ACCESS;
            if (!addr_valid) begin
              pslverr <= 1'b1;
              pready  <= 1'b1;
            end else if (pwrite) begin
              // Byte-lane write with strobes
              for (int i = 0; i < DATA_WIDTH/8; i++) begin
                if (pstrb[i])
                  mem[word_addr][i*8 +: 8] <= pwdata[i*8 +: 8];
              end
              pready <= 1'b1;
            end else begin
              prdata <= mem[word_addr];
              pready <= 1'b1;
            end
          end
        end

        ACCESS: begin
          state  <= IDLE;
          pready <= 1'b1;
        end

        default: state <= IDLE;
      endcase
    end
  end

endmodule
