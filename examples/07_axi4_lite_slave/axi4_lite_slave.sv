// AXI4-Lite Slave Interface
// Implements a memory-mapped register file with 4 registers.
// Compliant with AMBA AXI4-Lite protocol specification.
//
// Register Map:
//   0x00 - CTRL    (RW)  Control register
//   0x04 - STATUS  (RO)  Status register
//   0x08 - DATA0   (RW)  General-purpose data register 0
//   0x0C - DATA1   (RW)  General-purpose data register 1

module axi4_lite_slave #(
    parameter int ADDR_WIDTH = 4,
    parameter int DATA_WIDTH = 32
) (
    // Global signals
    input  logic                    aclk,
    input  logic                    aresetn,

    // Write address channel
    input  logic [ADDR_WIDTH-1:0]   s_axi_awaddr,
    input  logic                    s_axi_awvalid,
    output logic                    s_axi_awready,

    // Write data channel
    input  logic [DATA_WIDTH-1:0]   s_axi_wdata,
    input  logic [DATA_WIDTH/8-1:0] s_axi_wstrb,
    input  logic                    s_axi_wvalid,
    output logic                    s_axi_wready,

    // Write response channel
    output logic [1:0]              s_axi_bresp,
    output logic                    s_axi_bvalid,
    input  logic                    s_axi_bready,

    // Read address channel
    input  logic [ADDR_WIDTH-1:0]   s_axi_araddr,
    input  logic                    s_axi_arvalid,
    output logic                    s_axi_arready,

    // Read data channel
    output logic [DATA_WIDTH-1:0]   s_axi_rdata,
    output logic [1:0]              s_axi_rresp,
    output logic                    s_axi_rvalid,
    input  logic                    s_axi_rready,

    // User-facing register outputs
    output logic [DATA_WIDTH-1:0]   reg_ctrl,
    input  logic [DATA_WIDTH-1:0]   reg_status,
    output logic [DATA_WIDTH-1:0]   reg_data0,
    output logic [DATA_WIDTH-1:0]   reg_data1
);

    // AXI response codes
    localparam logic [1:0] RESP_OKAY   = 2'b00;
    localparam logic [1:0] RESP_SLVERR = 2'b10;

    // Internal address latches
    logic [ADDR_WIDTH-1:0] awaddr_reg;
    logic [ADDR_WIDTH-1:0] araddr_reg;

    // Handshake tracking
    logic aw_done;  // Write address received
    logic w_done;   // Write data received

    // --- Write Address Channel ---
    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            s_axi_awready <= 1'b0;
            awaddr_reg    <= '0;
            aw_done       <= 1'b0;
        end else begin
            if (s_axi_awvalid && !aw_done && !s_axi_awready) begin
                s_axi_awready <= 1'b1;
                awaddr_reg    <= s_axi_awaddr;
            end else begin
                s_axi_awready <= 1'b0;
            end

            if (s_axi_awvalid && s_axi_awready)
                aw_done <= 1'b1;
            else if (s_axi_bvalid && s_axi_bready)
                aw_done <= 1'b0;
        end
    end

    // --- Write Data Channel ---
    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            s_axi_wready <= 1'b0;
            w_done       <= 1'b0;
        end else begin
            if (s_axi_wvalid && !w_done && !s_axi_wready)
                s_axi_wready <= 1'b1;
            else
                s_axi_wready <= 1'b0;

            if (s_axi_wvalid && s_axi_wready)
                w_done <= 1'b1;
            else if (s_axi_bvalid && s_axi_bready)
                w_done <= 1'b0;
        end
    end

    // --- Register Write Logic ---
    // Write occurs when both address and data handshakes are complete
    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            reg_ctrl  <= '0;
            reg_data0 <= '0;
            reg_data1 <= '0;
        end else if (aw_done && w_done) begin
            case (awaddr_reg[3:2])
                2'b00: begin // CTRL (0x00)
                    for (int i = 0; i < DATA_WIDTH/8; i++) begin
                        if (s_axi_wstrb[i])
                            reg_ctrl[i*8 +: 8] <= s_axi_wdata[i*8 +: 8];
                    end
                end
                2'b01: begin // STATUS (0x04) - read only, ignore writes
                end
                2'b10: begin // DATA0 (0x08)
                    for (int i = 0; i < DATA_WIDTH/8; i++) begin
                        if (s_axi_wstrb[i])
                            reg_data0[i*8 +: 8] <= s_axi_wdata[i*8 +: 8];
                    end
                end
                2'b11: begin // DATA1 (0x0C)
                    for (int i = 0; i < DATA_WIDTH/8; i++) begin
                        if (s_axi_wstrb[i])
                            reg_data1[i*8 +: 8] <= s_axi_wdata[i*8 +: 8];
                    end
                end
            endcase
        end
    end

    // --- Write Response Channel ---
    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            s_axi_bvalid <= 1'b0;
            s_axi_bresp  <= RESP_OKAY;
        end else if (aw_done && w_done && !s_axi_bvalid) begin
            s_axi_bvalid <= 1'b1;
            s_axi_bresp  <= RESP_OKAY;
        end else if (s_axi_bvalid && s_axi_bready) begin
            s_axi_bvalid <= 1'b0;
        end
    end

    // --- Read Address Channel ---
    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            s_axi_arready <= 1'b0;
            araddr_reg    <= '0;
        end else if (s_axi_arvalid && !s_axi_arready && !s_axi_rvalid) begin
            s_axi_arready <= 1'b1;
            araddr_reg    <= s_axi_araddr;
        end else begin
            s_axi_arready <= 1'b0;
        end
    end

    // --- Read Data Channel ---
    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            s_axi_rdata  <= '0;
            s_axi_rresp  <= RESP_OKAY;
            s_axi_rvalid <= 1'b0;
        end else if (s_axi_arready && s_axi_arvalid) begin
            s_axi_rvalid <= 1'b1;
            s_axi_rresp  <= RESP_OKAY;

            case (araddr_reg[3:2])
                2'b00: s_axi_rdata <= reg_ctrl;
                2'b01: s_axi_rdata <= reg_status;
                2'b10: s_axi_rdata <= reg_data0;
                2'b11: s_axi_rdata <= reg_data1;
            endcase
        end else if (s_axi_rvalid && s_axi_rready) begin
            s_axi_rvalid <= 1'b0;
        end
    end

endmodule
