// AXI4-Lite Slave — register bank with configurable number of registers.
//
// AXI4-Lite is the simplest AXI variant, used for configuration/status registers.
// This module implements the 5 AXI4-Lite channels:
//   - Write Address (AW), Write Data (W), Write Response (B)
//   - Read Address (AR), Read Data (R)
//
// All transfers are single-beat (no bursts in AXI4-Lite).

module axi_lite_slave #(
    parameter int ADDR_WIDTH = 8,
    parameter int DATA_WIDTH = 32,
    parameter int NUM_REGS   = 16
)(
    input  logic                  aclk,
    input  logic                  aresetn,

    // Write Address Channel
    input  logic [ADDR_WIDTH-1:0] s_axi_awaddr,
    input  logic                  s_axi_awvalid,
    output logic                  s_axi_awready,

    // Write Data Channel
    input  logic [DATA_WIDTH-1:0]   s_axi_wdata,
    input  logic [DATA_WIDTH/8-1:0] s_axi_wstrb,
    input  logic                    s_axi_wvalid,
    output logic                    s_axi_wready,

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
    input  logic                  s_axi_rready
);

    localparam int BYTE_ADDR_BITS = $clog2(DATA_WIDTH / 8);
    localparam int REG_ADDR_BITS  = $clog2(NUM_REGS);

    // Register storage
    logic [DATA_WIDTH-1:0] regs [0:NUM_REGS-1];

    // Internal address latches
    logic [ADDR_WIDTH-1:0] aw_addr_latched;
    logic [ADDR_WIDTH-1:0] ar_addr_latched;

    // AW/W handshake flags
    logic aw_done, w_done;

    // =========================================================================
    // Write Address Channel
    // =========================================================================
    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            s_axi_awready  <= 1'b0;
            aw_addr_latched <= '0;
            aw_done         <= 1'b0;
        end else if (s_axi_awvalid && !aw_done) begin
            s_axi_awready  <= 1'b1;
            aw_addr_latched <= s_axi_awaddr;
            aw_done         <= 1'b1;
        end else begin
            s_axi_awready <= 1'b0;
            if (s_axi_bvalid && s_axi_bready)
                aw_done <= 1'b0;
        end
    end

    // =========================================================================
    // Write Data Channel
    // =========================================================================
    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            s_axi_wready <= 1'b0;
            w_done       <= 1'b0;
        end else if (s_axi_wvalid && !w_done) begin
            s_axi_wready <= 1'b1;
            w_done       <= 1'b1;
        end else begin
            s_axi_wready <= 1'b0;
            if (s_axi_bvalid && s_axi_bready)
                w_done <= 1'b0;
        end
    end

    // =========================================================================
    // Register Write (when both AW and W are done)
    // =========================================================================
    logic [REG_ADDR_BITS-1:0] wr_reg_idx;
    assign wr_reg_idx = aw_addr_latched[BYTE_ADDR_BITS +: REG_ADDR_BITS];

    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            for (int i = 0; i < NUM_REGS; i++)
                regs[i] <= '0;
        end else if (aw_done && w_done && !(s_axi_bvalid && !s_axi_bready)) begin
            if (wr_reg_idx < NUM_REGS[REG_ADDR_BITS-1:0]) begin
                for (int b = 0; b < DATA_WIDTH/8; b++) begin
                    if (s_axi_wstrb[b])
                        regs[wr_reg_idx][b*8 +: 8] <= s_axi_wdata[b*8 +: 8];
                end
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
        end else if (aw_done && w_done && !s_axi_bvalid) begin
            s_axi_bvalid <= 1'b1;
            s_axi_bresp  <= (wr_reg_idx < NUM_REGS[REG_ADDR_BITS-1:0]) ? 2'b00 : 2'b11;
        end else if (s_axi_bvalid && s_axi_bready) begin
            s_axi_bvalid <= 1'b0;
        end
    end

    // =========================================================================
    // Read Address Channel
    // =========================================================================
    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            s_axi_arready  <= 1'b0;
            ar_addr_latched <= '0;
        end else if (s_axi_arvalid && !s_axi_arready && !s_axi_rvalid) begin
            s_axi_arready  <= 1'b1;
            ar_addr_latched <= s_axi_araddr;
        end else begin
            s_axi_arready <= 1'b0;
        end
    end

    // =========================================================================
    // Read Data Channel
    // =========================================================================
    logic [REG_ADDR_BITS-1:0] rd_reg_idx;
    assign rd_reg_idx = ar_addr_latched[BYTE_ADDR_BITS +: REG_ADDR_BITS];

    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            s_axi_rvalid <= 1'b0;
            s_axi_rdata  <= '0;
            s_axi_rresp  <= 2'b00;
        end else if (s_axi_arready) begin
            s_axi_rvalid <= 1'b1;
            if (rd_reg_idx < NUM_REGS[REG_ADDR_BITS-1:0]) begin
                s_axi_rdata <= regs[rd_reg_idx];
                s_axi_rresp <= 2'b00;
            end else begin
                s_axi_rdata <= '0;
                s_axi_rresp <= 2'b11;   // DECERR
            end
        end else if (s_axi_rvalid && s_axi_rready) begin
            s_axi_rvalid <= 1'b0;
        end
    end

endmodule
