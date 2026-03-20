// AXI4-Lite slave with 16 32-bit registers
module axi_lite_slave #(
  parameter ADDR_WIDTH = 6,
  parameter DATA_WIDTH = 32,
  parameter NUM_REGS   = 16
)(
  input  logic                    aclk,
  input  logic                    aresetn,

  // Write address channel
  input  logic [ADDR_WIDTH-1:0]   s_awaddr,
  input  logic                    s_awvalid,
  output logic                    s_awready,

  // Write data channel
  input  logic [DATA_WIDTH-1:0]   s_wdata,
  input  logic [DATA_WIDTH/8-1:0] s_wstrb,
  input  logic                    s_wvalid,
  output logic                    s_wready,

  // Write response channel
  output logic [1:0]              s_bresp,
  output logic                    s_bvalid,
  input  logic                    s_bready,

  // Read address channel
  input  logic [ADDR_WIDTH-1:0]   s_araddr,
  input  logic                    s_arvalid,
  output logic                    s_arready,

  // Read data channel
  output logic [DATA_WIDTH-1:0]   s_rdata,
  output logic [1:0]              s_rresp,
  output logic                    s_rvalid,
  input  logic                    s_rready
);

  localparam ADDR_LSB = $clog2(DATA_WIDTH / 8);

  logic [DATA_WIDTH-1:0] regs [NUM_REGS];

  // Write FSM
  typedef enum logic [1:0] {
    WR_IDLE,
    WR_DATA,
    WR_RESP
  } wr_state_e;

  wr_state_e wr_state;
  logic [ADDR_WIDTH-1:0] wr_addr;

  always_ff @(posedge aclk or negedge aresetn) begin
    if (!aresetn) begin
      wr_state  <= WR_IDLE;
      s_awready <= 1'b0;
      s_wready  <= 1'b0;
      s_bvalid  <= 1'b0;
      s_bresp   <= 2'b00;
      wr_addr   <= '0;
      for (int i = 0; i < NUM_REGS; i++)
        regs[i] <= '0;
    end else begin
      case (wr_state)
        WR_IDLE: begin
          s_awready <= 1'b1;
          s_bvalid  <= 1'b0;
          if (s_awvalid && s_awready) begin
            wr_addr   <= s_awaddr;
            s_awready <= 1'b0;
            s_wready  <= 1'b1;
            wr_state  <= WR_DATA;
          end
        end

        WR_DATA: begin
          if (s_wvalid && s_wready) begin
            for (int i = 0; i < DATA_WIDTH/8; i++) begin
              if (s_wstrb[i])
                regs[wr_addr[ADDR_WIDTH-1:ADDR_LSB]][i*8 +: 8] <= s_wdata[i*8 +: 8];
            end
            s_wready <= 1'b0;
            s_bvalid <= 1'b1;
            s_bresp  <= 2'b00;  // OKAY
            wr_state <= WR_RESP;
          end
        end

        WR_RESP: begin
          if (s_bvalid && s_bready) begin
            s_bvalid <= 1'b0;
            wr_state <= WR_IDLE;
          end
        end
      endcase
    end
  end

  // Read FSM
  typedef enum logic [1:0] {
    RD_IDLE,
    RD_DATA
  } rd_state_e;

  rd_state_e rd_state;

  always_ff @(posedge aclk or negedge aresetn) begin
    if (!aresetn) begin
      rd_state  <= RD_IDLE;
      s_arready <= 1'b0;
      s_rvalid  <= 1'b0;
      s_rdata   <= '0;
      s_rresp   <= 2'b00;
    end else begin
      case (rd_state)
        RD_IDLE: begin
          s_arready <= 1'b1;
          if (s_arvalid && s_arready) begin
            s_arready <= 1'b0;
            s_rdata   <= regs[s_araddr[ADDR_WIDTH-1:ADDR_LSB]];
            s_rresp   <= 2'b00;  // OKAY
            s_rvalid  <= 1'b1;
            rd_state  <= RD_DATA;
          end
        end

        RD_DATA: begin
          if (s_rvalid && s_rready) begin
            s_rvalid <= 1'b0;
            rd_state <= RD_IDLE;
          end
        end
      endcase
    end
  end

endmodule
