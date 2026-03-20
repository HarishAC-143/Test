// Simple peripheral with APB slave interface and registers
module periph_dut (
  input  logic        pclk,
  input  logic        preset_n,
  // APB slave interface
  input  logic        psel,
  input  logic        penable,
  input  logic        pwrite,
  input  logic [7:0]  paddr,
  input  logic [31:0] pwdata,
  output logic [31:0] prdata,
  output logic        pready,
  // Interrupt output
  output logic        irq
);

  // Register addresses
  localparam CTRL_ADDR       = 8'h00;
  localparam STATUS_ADDR     = 8'h04;
  localparam DATA_IN_ADDR    = 8'h08;
  localparam DATA_OUT_ADDR   = 8'h0C;
  localparam IRQ_STATUS_ADDR = 8'h10;

  // Registers
  logic [31:0] ctrl_reg;
  logic [31:0] status_reg;
  logic [31:0] data_in_reg;
  logic [31:0] data_out_reg;
  logic [31:0] irq_status_reg;

  // CTRL register fields
  wire ctrl_enable = ctrl_reg[0];
  wire [1:0] ctrl_mode = ctrl_reg[2:1];
  wire ctrl_irq_en = ctrl_reg[3];

  // STATUS register fields
  wire status_busy = status_reg[0];
  wire status_done = status_reg[1];
  wire status_error = status_reg[2];

  // APB ready — always ready in 1 cycle
  assign pready = 1'b1;

  // Interrupt output
  assign irq = ctrl_irq_en && (|irq_status_reg);

  // Simple data processing: when enabled, output = input processed by mode
  always_ff @(posedge pclk or negedge preset_n) begin
    if (!preset_n) begin
      data_out_reg <= 32'h0;
      status_reg   <= 32'h0;
    end else if (ctrl_enable) begin
      case (ctrl_mode)
        2'b00: data_out_reg <= data_in_reg;                    // pass-through
        2'b01: data_out_reg <= data_in_reg + 32'h1;            // increment
        2'b10: data_out_reg <= {data_in_reg[15:0], data_in_reg[31:16]}; // swap halves
        2'b11: data_out_reg <= ~data_in_reg;                   // invert
      endcase
      status_reg[1] <= 1'b1;  // done
      status_reg[0] <= 1'b0;  // not busy
    end
  end

  // APB write
  always_ff @(posedge pclk or negedge preset_n) begin
    if (!preset_n) begin
      ctrl_reg       <= 32'h0;
      data_in_reg    <= 32'h0;
      irq_status_reg <= 32'h0;
    end else if (psel && penable && pwrite && pready) begin
      case (paddr)
        CTRL_ADDR:       ctrl_reg <= pwdata;
        DATA_IN_ADDR:    data_in_reg <= pwdata;
        IRQ_STATUS_ADDR: irq_status_reg <= irq_status_reg & ~pwdata; // W1C
        default: ;
      endcase
    end
  end

  // APB read
  always_comb begin
    prdata = 32'h0;
    if (psel && !pwrite) begin
      case (paddr)
        CTRL_ADDR:       prdata = ctrl_reg;
        STATUS_ADDR:     prdata = status_reg;
        DATA_IN_ADDR:    prdata = data_in_reg;
        DATA_OUT_ADDR:   prdata = data_out_reg;
        IRQ_STATUS_ADDR: prdata = irq_status_reg;
        default:         prdata = 32'hDEAD_BEEF;
      endcase
    end
  end

endmodule
