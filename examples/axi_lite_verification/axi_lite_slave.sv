// DUT: AXI4-Lite slave with 4 x 32-bit registers
module axi_lite_slave (
  input  logic        aclk,
  input  logic        aresetn,

  // Write Address Channel
  input  logic [31:0] s_axi_awaddr,
  input  logic        s_axi_awvalid,
  output logic        s_axi_awready,

  // Write Data Channel
  input  logic [31:0] s_axi_wdata,
  input  logic [3:0]  s_axi_wstrb,
  input  logic        s_axi_wvalid,
  output logic        s_axi_wready,

  // Write Response Channel
  output logic [1:0]  s_axi_bresp,
  output logic        s_axi_bvalid,
  input  logic        s_axi_bready,

  // Read Address Channel
  input  logic [31:0] s_axi_araddr,
  input  logic        s_axi_arvalid,
  output logic        s_axi_arready,

  // Read Data Channel
  output logic [31:0] s_axi_rdata,
  output logic [1:0]  s_axi_rresp,
  output logic        s_axi_rvalid,
  input  logic        s_axi_rready
);

  // Register bank: 4 registers at word-aligned addresses
  logic [31:0] registers [0:3];

  // Internal signals
  logic        aw_handshake;
  logic        w_handshake;
  logic        ar_handshake;

  logic [31:0] aw_addr_reg;
  logic        aw_addr_valid;
  logic [31:0] w_data_reg;
  logic [3:0]  w_strb_reg;
  logic        w_data_valid;

  assign aw_handshake = s_axi_awvalid & s_axi_awready;
  assign w_handshake  = s_axi_wvalid  & s_axi_wready;
  assign ar_handshake = s_axi_arvalid & s_axi_arready;

  // Write address channel
  always_ff @(posedge aclk or negedge aresetn) begin
    if (!aresetn) begin
      s_axi_awready <= 1'b1;
      aw_addr_reg   <= 32'd0;
      aw_addr_valid <= 1'b0;
    end else begin
      if (aw_handshake) begin
        aw_addr_reg   <= s_axi_awaddr;
        aw_addr_valid <= 1'b1;
        s_axi_awready <= 1'b0;
      end
      if (aw_addr_valid && w_data_valid) begin
        aw_addr_valid <= 1'b0;
        s_axi_awready <= 1'b1;
      end
    end
  end

  // Write data channel
  always_ff @(posedge aclk or negedge aresetn) begin
    if (!aresetn) begin
      s_axi_wready <= 1'b1;
      w_data_reg   <= 32'd0;
      w_strb_reg   <= 4'd0;
      w_data_valid <= 1'b0;
    end else begin
      if (w_handshake) begin
        w_data_reg   <= s_axi_wdata;
        w_strb_reg   <= s_axi_wstrb;
        w_data_valid <= 1'b1;
        s_axi_wready <= 1'b0;
      end
      if (aw_addr_valid && w_data_valid) begin
        w_data_valid <= 1'b0;
        s_axi_wready <= 1'b1;
      end
    end
  end

  // Write to registers
  always_ff @(posedge aclk or negedge aresetn) begin
    if (!aresetn) begin
      for (int i = 0; i < 4; i++)
        registers[i] <= 32'd0;
    end else if (aw_addr_valid && w_data_valid) begin
      automatic int reg_idx = aw_addr_reg[3:2];
      if (reg_idx < 4) begin
        if (w_strb_reg[0]) registers[reg_idx][ 7: 0] <= w_data_reg[ 7: 0];
        if (w_strb_reg[1]) registers[reg_idx][15: 8] <= w_data_reg[15: 8];
        if (w_strb_reg[2]) registers[reg_idx][23:16] <= w_data_reg[23:16];
        if (w_strb_reg[3]) registers[reg_idx][31:24] <= w_data_reg[31:24];
      end
    end
  end

  // Write response
  always_ff @(posedge aclk or negedge aresetn) begin
    if (!aresetn) begin
      s_axi_bvalid <= 1'b0;
      s_axi_bresp  <= 2'b00;
    end else begin
      if (aw_addr_valid && w_data_valid) begin
        s_axi_bvalid <= 1'b1;
        s_axi_bresp  <= (aw_addr_reg[3:2] < 4) ? 2'b00 : 2'b11;  // OKAY or DECERR
      end else if (s_axi_bvalid && s_axi_bready) begin
        s_axi_bvalid <= 1'b0;
      end
    end
  end

  // Read address channel
  always_ff @(posedge aclk or negedge aresetn) begin
    if (!aresetn) begin
      s_axi_arready <= 1'b1;
      s_axi_rdata   <= 32'd0;
      s_axi_rresp   <= 2'b00;
      s_axi_rvalid  <= 1'b0;
    end else begin
      if (ar_handshake) begin
        automatic int reg_idx = s_axi_araddr[3:2];
        s_axi_arready <= 1'b0;
        s_axi_rvalid  <= 1'b1;
        if (reg_idx < 4) begin
          s_axi_rdata <= registers[reg_idx];
          s_axi_rresp <= 2'b00;  // OKAY
        end else begin
          s_axi_rdata <= 32'd0;
          s_axi_rresp <= 2'b11;  // DECERR
        end
      end else if (s_axi_rvalid && s_axi_rready) begin
        s_axi_rvalid  <= 1'b0;
        s_axi_arready <= 1'b1;
      end
    end
  end

endmodule
