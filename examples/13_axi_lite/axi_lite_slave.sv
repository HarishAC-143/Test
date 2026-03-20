// AXI4-Lite Slave Register Bank
// Implements a simple register file accessible via the AXI4-Lite protocol.
// AXI4-Lite is the standard interface for configuration/control registers
// in FPGA SoC designs (e.g., Xilinx Zynq, Intel FPGA SoC).

module axi_lite_slave #(
    parameter int ADDR_WIDTH = 8,
    parameter int DATA_WIDTH = 32,
    parameter int NUM_REGS   = 16
) (
    input  logic                  aclk,
    input  logic                  aresetn,

    // Write Address Channel
    input  logic [ADDR_WIDTH-1:0] s_axi_awaddr,
    input  logic                  s_axi_awvalid,
    output logic                  s_axi_awready,

    // Write Data Channel
    input  logic [DATA_WIDTH-1:0] s_axi_wdata,
    input  logic [DATA_WIDTH/8-1:0] s_axi_wstrb,
    input  logic                  s_axi_wvalid,
    output logic                  s_axi_wready,

    // Write Response Channel
    output logic [1:0]            s_axi_bresp,
    output logic                  s_axi_bvalid,
    input  logic                  s_axi_bready,

    // Read Address Channel
    input  logic [ADDR_WIDTH-1:0] s_axi_araddr,
    input  logic                  s_axi_arvalid,
    output logic                  s_axi_arready,

    // Read Data Channel
    output logic [DATA_WIDTH-1:0] s_axi_rdata,
    output logic [1:0]            s_axi_rresp,
    output logic                  s_axi_rvalid,
    input  logic                  s_axi_rready,

    // Register outputs (directly accessible by user logic)
    output logic [DATA_WIDTH-1:0] reg_control,
    output logic [DATA_WIDTH-1:0] reg_config,
    input  logic [DATA_WIDTH-1:0] reg_status,
    input  logic [DATA_WIDTH-1:0] reg_debug
);

    // Register map (word-addressed, byte offset = index * 4)
    localparam int REG_CONTROL = 0;  // R/W - Control register
    localparam int REG_STATUS  = 1;  // R   - Status register (read-only)
    localparam int REG_CONFIG  = 2;  // R/W - Configuration register
    localparam int REG_DEBUG   = 3;  // R   - Debug register (read-only)

    // Internal register storage
    logic [DATA_WIDTH-1:0] regs [NUM_REGS];

    // Write address and data acceptance
    logic aw_accepted, w_accepted;
    logic [ADDR_WIDTH-1:0] aw_addr_reg;

    // =========================================================================
    // Write Address Channel
    // =========================================================================
    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            s_axi_awready <= 1'b0;
            aw_accepted   <= 1'b0;
            aw_addr_reg   <= '0;
        end else begin
            if (s_axi_awvalid && !aw_accepted) begin
                s_axi_awready <= 1'b1;
                aw_accepted   <= 1'b1;
                aw_addr_reg   <= s_axi_awaddr;
            end else begin
                s_axi_awready <= 1'b0;
            end
            if (s_axi_bvalid && s_axi_bready)
                aw_accepted <= 1'b0;
        end
    end

    // =========================================================================
    // Write Data Channel
    // =========================================================================
    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            s_axi_wready <= 1'b0;
            w_accepted   <= 1'b0;
        end else begin
            if (s_axi_wvalid && !w_accepted) begin
                s_axi_wready <= 1'b1;
                w_accepted   <= 1'b1;
            end else begin
                s_axi_wready <= 1'b0;
            end
            if (s_axi_bvalid && s_axi_bready)
                w_accepted <= 1'b0;
        end
    end

    // =========================================================================
    // Write to registers (with byte strobes)
    // =========================================================================
    wire [ADDR_WIDTH-1:0] wr_word_addr = aw_addr_reg[ADDR_WIDTH-1:2];

    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            for (int i = 0; i < NUM_REGS; i++)
                regs[i] <= '0;
        end else if (aw_accepted && w_accepted) begin
            for (int b = 0; b < DATA_WIDTH/8; b++) begin
                if (s_axi_wstrb[b])
                    regs[wr_word_addr][b*8 +: 8] <= s_axi_wdata[b*8 +: 8];
            end
        end
    end

    // =========================================================================
    // Write Response Channel
    // =========================================================================
    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            s_axi_bvalid <= 1'b0;
            s_axi_bresp  <= 2'b00;
        end else begin
            if (aw_accepted && w_accepted && !s_axi_bvalid) begin
                s_axi_bvalid <= 1'b1;
                s_axi_bresp  <= 2'b00;  // OKAY
            end else if (s_axi_bready) begin
                s_axi_bvalid <= 1'b0;
            end
        end
    end

    // =========================================================================
    // Read Address + Data Channel
    // =========================================================================
    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            s_axi_arready <= 1'b0;
            s_axi_rvalid  <= 1'b0;
            s_axi_rdata   <= '0;
            s_axi_rresp   <= 2'b00;
        end else begin
            if (s_axi_arvalid && !s_axi_rvalid) begin
                s_axi_arready <= 1'b1;
                s_axi_rvalid  <= 1'b1;
                s_axi_rresp   <= 2'b00;

                unique case (s_axi_araddr[ADDR_WIDTH-1:2])
                    REG_CONTROL[ADDR_WIDTH-3:0]: s_axi_rdata <= regs[REG_CONTROL];
                    REG_STATUS[ADDR_WIDTH-3:0]:  s_axi_rdata <= reg_status;
                    REG_CONFIG[ADDR_WIDTH-3:0]:  s_axi_rdata <= regs[REG_CONFIG];
                    REG_DEBUG[ADDR_WIDTH-3:0]:   s_axi_rdata <= reg_debug;
                    default:                     s_axi_rdata <= 32'hDEAD_BEEF;
                endcase
            end else begin
                s_axi_arready <= 1'b0;
                if (s_axi_rready)
                    s_axi_rvalid <= 1'b0;
            end
        end
    end

    // Map internal regs to output ports
    assign reg_control = regs[REG_CONTROL];
    assign reg_config  = regs[REG_CONFIG];

endmodule
