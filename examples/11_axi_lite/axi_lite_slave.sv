// ============================================================================
// AXI4-Lite Slave — Register File
// ============================================================================
// A synthesizable AXI4-Lite slave that implements a configurable number of
// 32-bit read/write registers. This is the standard pattern for FPGA IP
// that needs to be controlled by a processor (e.g., Zynq PS, MicroBlaze).
//
// Features:
//   - Configurable address width and number of registers
//   - Byte-enable (write strobe) support
//   - Separate read and write FSMs for independent channel handling
//   - OKAY response on all valid accesses
// ============================================================================

module axi_lite_slave #(
    parameter int ADDR_WIDTH = 8,
    parameter int DATA_WIDTH = 32,
    parameter int NUM_REGS   = 16
)(
    input  logic                    aclk,
    input  logic                    aresetn,

    // Write Address Channel
    input  logic [ADDR_WIDTH-1:0]   s_awaddr,
    input  logic                    s_awvalid,
    output logic                    s_awready,

    // Write Data Channel
    input  logic [DATA_WIDTH-1:0]   s_wdata,
    input  logic [DATA_WIDTH/8-1:0] s_wstrb,
    input  logic                    s_wvalid,
    output logic                    s_wready,

    // Write Response Channel
    output logic [1:0]              s_bresp,
    output logic                    s_bvalid,
    input  logic                    s_bready,

    // Read Address Channel
    input  logic [ADDR_WIDTH-1:0]   s_araddr,
    input  logic                    s_arvalid,
    output logic                    s_arready,

    // Read Data Channel
    output logic [DATA_WIDTH-1:0]   s_rdata,
    output logic [1:0]              s_rresp,
    output logic                    s_rvalid,
    input  logic                    s_rready
);

    localparam int ADDR_LSB   = $clog2(DATA_WIDTH / 8);
    localparam int REG_ADDR_W = $clog2(NUM_REGS);

    // Register file
    logic [DATA_WIDTH-1:0] regs [NUM_REGS];

    // -------------------------------------------------------------------------
    // Write Path FSM
    // -------------------------------------------------------------------------
    typedef enum logic [1:0] {
        WR_IDLE,
        WR_DATA,
        WR_RESP
    } wr_state_t;

    wr_state_t              wr_state;
    logic [ADDR_WIDTH-1:0]  wr_addr_latched;

    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            wr_state        <= WR_IDLE;
            s_awready       <= 1'b0;
            s_wready        <= 1'b0;
            s_bvalid        <= 1'b0;
            s_bresp         <= 2'b00;
            wr_addr_latched <= '0;
            for (int i = 0; i < NUM_REGS; i++)
                regs[i] <= '0;
        end else begin
            unique case (wr_state)
                WR_IDLE: begin
                    s_bvalid  <= 1'b0;
                    s_awready <= 1'b1;
                    s_wready  <= 1'b0;
                    if (s_awvalid && s_awready) begin
                        wr_addr_latched <= s_awaddr;
                        s_awready       <= 1'b0;
                        s_wready        <= 1'b1;
                        wr_state        <= WR_DATA;
                    end
                end

                WR_DATA: begin
                    if (s_wvalid && s_wready) begin
                        for (int b = 0; b < DATA_WIDTH/8; b++) begin
                            if (s_wstrb[b])
                                regs[wr_addr_latched[ADDR_LSB +: REG_ADDR_W]][b*8 +: 8]
                                    <= s_wdata[b*8 +: 8];
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

                default: wr_state <= WR_IDLE;
            endcase
        end
    end

    // -------------------------------------------------------------------------
    // Read Path FSM
    // -------------------------------------------------------------------------
    typedef enum logic {
        RD_IDLE,
        RD_DATA
    } rd_state_t;

    rd_state_t rd_state;

    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            rd_state  <= RD_IDLE;
            s_arready <= 1'b0;
            s_rvalid  <= 1'b0;
            s_rdata   <= '0;
            s_rresp   <= 2'b00;
        end else begin
            unique case (rd_state)
                RD_IDLE: begin
                    s_arready <= 1'b1;
                    s_rvalid  <= 1'b0;
                    if (s_arvalid && s_arready) begin
                        s_rdata   <= regs[s_araddr[ADDR_LSB +: REG_ADDR_W]];
                        s_rresp   <= 2'b00;  // OKAY
                        s_arready <= 1'b0;
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

                default: rd_state <= RD_IDLE;
            endcase
        end
    end

endmodule
