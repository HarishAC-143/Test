// ----------------------------------------------------------------------------
// AXI4-Lite Slave Interface with Register Bank
// Demonstrates: AMBA AXI4-Lite protocol, handshake signaling,
//               memory-mapped register file, read/write channels
// ----------------------------------------------------------------------------

module axi_lite_slave #(
    parameter int ADDR_WIDTH   = 12,
    parameter int DATA_WIDTH   = 32,
    parameter int NUM_REGS     = 16
)(
    // Global signals
    input  logic                    aclk,
    input  logic                    aresetn,

    // Write address channel
    input  logic [ADDR_WIDTH-1:0]   s_axi_awaddr,
    input  logic [2:0]              s_axi_awprot,
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
    input  logic [2:0]              s_axi_arprot,
    input  logic                    s_axi_arvalid,
    output logic                    s_axi_arready,

    // Read data channel
    output logic [DATA_WIDTH-1:0]   s_axi_rdata,
    output logic [1:0]              s_axi_rresp,
    output logic                    s_axi_rvalid,
    input  logic                    s_axi_rready,

    // Register outputs (directly accessible by user logic)
    output logic [DATA_WIDTH-1:0]   reg_out [NUM_REGS],

    // Interrupt status register input from hardware
    input  logic [DATA_WIDTH-1:0]   irq_status
);

    localparam int REG_ADDR_BITS = $clog2(NUM_REGS) + 2;
    localparam logic [1:0] RESP_OKAY   = 2'b00;
    localparam logic [1:0] RESP_DECERR = 2'b11;

    // Internal register file
    logic [DATA_WIDTH-1:0] registers [NUM_REGS];

    // Address latches
    logic [ADDR_WIDTH-1:0] aw_addr_latched;
    logic [ADDR_WIDTH-1:0] ar_addr_latched;

    // State for write channel
    typedef enum logic [1:0] {
        WR_IDLE,
        WR_DATA,
        WR_RESP
    } wr_state_t;

    // State for read channel
    typedef enum logic [1:0] {
        RD_IDLE,
        RD_DATA
    } rd_state_t;

    wr_state_t wr_state;
    rd_state_t rd_state;

    // ===== Write Channel =====
    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            wr_state        <= WR_IDLE;
            s_axi_awready   <= 1'b0;
            s_axi_wready    <= 1'b0;
            s_axi_bvalid    <= 1'b0;
            s_axi_bresp     <= RESP_OKAY;
            aw_addr_latched <= '0;
            for (int i = 0; i < NUM_REGS; i++)
                registers[i] <= '0;
        end else begin
            case (wr_state)
                WR_IDLE: begin
                    s_axi_bvalid <= 1'b0;
                    if (s_axi_awvalid) begin
                        s_axi_awready   <= 1'b1;
                        aw_addr_latched <= s_axi_awaddr;
                        wr_state        <= WR_DATA;
                    end
                end

                WR_DATA: begin
                    s_axi_awready <= 1'b0;
                    s_axi_wready  <= 1'b1;
                    if (s_axi_wvalid) begin
                        s_axi_wready <= 1'b0;

                        // Byte-lane write with strobe support
                        if (aw_addr_latched[REG_ADDR_BITS-1:2] < NUM_REGS) begin
                            for (int b = 0; b < DATA_WIDTH/8; b++) begin
                                if (s_axi_wstrb[b])
                                    registers[aw_addr_latched[REG_ADDR_BITS-1:2]][b*8 +: 8]
                                        <= s_axi_wdata[b*8 +: 8];
                            end
                            s_axi_bresp <= RESP_OKAY;
                        end else begin
                            s_axi_bresp <= RESP_DECERR;
                        end

                        s_axi_bvalid <= 1'b1;
                        wr_state     <= WR_RESP;
                    end
                end

                WR_RESP: begin
                    if (s_axi_bready) begin
                        s_axi_bvalid <= 1'b0;
                        wr_state     <= WR_IDLE;
                    end
                end

                default: wr_state <= WR_IDLE;
            endcase
        end
    end

    // ===== Read Channel =====
    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            rd_state        <= RD_IDLE;
            s_axi_arready   <= 1'b0;
            s_axi_rvalid    <= 1'b0;
            s_axi_rdata     <= '0;
            s_axi_rresp     <= RESP_OKAY;
            ar_addr_latched <= '0;
        end else begin
            case (rd_state)
                RD_IDLE: begin
                    s_axi_rvalid <= 1'b0;
                    if (s_axi_arvalid) begin
                        s_axi_arready   <= 1'b1;
                        ar_addr_latched <= s_axi_araddr;
                        rd_state        <= RD_DATA;
                    end
                end

                RD_DATA: begin
                    s_axi_arready <= 1'b0;
                    s_axi_rvalid  <= 1'b1;

                    if (ar_addr_latched[REG_ADDR_BITS-1:2] < NUM_REGS) begin
                        // Special handling for IRQ status register (e.g., reg 15)
                        if (ar_addr_latched[REG_ADDR_BITS-1:2] == NUM_REGS - 1)
                            s_axi_rdata <= irq_status;
                        else
                            s_axi_rdata <= registers[ar_addr_latched[REG_ADDR_BITS-1:2]];
                        s_axi_rresp <= RESP_OKAY;
                    end else begin
                        s_axi_rdata <= '0;
                        s_axi_rresp <= RESP_DECERR;
                    end

                    if (s_axi_rready) begin
                        s_axi_rvalid <= 1'b0;
                        rd_state     <= RD_IDLE;
                    end
                end

                default: rd_state <= RD_IDLE;
            endcase
        end
    end

    // Drive register outputs
    always_comb begin
        for (int i = 0; i < NUM_REGS; i++)
            reg_out[i] = registers[i];
    end

endmodule
