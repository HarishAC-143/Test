// =============================================================================
// AXI4-Lite Slave Register Interface
// Demonstrates: Standard bus protocols, interfaces, modports
// =============================================================================

interface axi_lite_if #(
    parameter int ADDR_WIDTH = 32,
    parameter int DATA_WIDTH = 32
) (
    input logic aclk,
    input logic aresetn
);
    // Write address channel
    logic [ADDR_WIDTH-1:0] awaddr;
    logic                  awvalid;
    logic                  awready;

    // Write data channel
    logic [DATA_WIDTH-1:0]   wdata;
    logic [DATA_WIDTH/8-1:0] wstrb;
    logic                    wvalid;
    logic                    wready;

    // Write response channel
    logic [1:0] bresp;
    logic       bvalid;
    logic       bready;

    // Read address channel
    logic [ADDR_WIDTH-1:0] araddr;
    logic                  arvalid;
    logic                  arready;

    // Read data channel
    logic [DATA_WIDTH-1:0] rdata;
    logic [1:0]            rresp;
    logic                  rvalid;
    logic                  rready;

    modport master (
        output awaddr, awvalid, wdata, wstrb, wvalid, bready,
               araddr, arvalid, rready,
        input  awready, wready, bresp, bvalid,
               arready, rdata, rresp, rvalid
    );

    modport slave (
        input  awaddr, awvalid, wdata, wstrb, wvalid, bready,
               araddr, arvalid, rready,
        output awready, wready, bresp, bvalid,
               arready, rdata, rresp, rvalid
    );
endinterface


module axi_lite_slave #(
    parameter int ADDR_WIDTH  = 12,
    parameter int DATA_WIDTH  = 32,
    parameter int NUM_REGS    = 16
) (
    input  logic clk,
    input  logic rst_n,

    // AXI-Lite signals (flat port version for broader compatibility)
    input  logic [ADDR_WIDTH-1:0]   s_axi_awaddr,
    input  logic                    s_axi_awvalid,
    output logic                    s_axi_awready,

    input  logic [DATA_WIDTH-1:0]   s_axi_wdata,
    input  logic [DATA_WIDTH/8-1:0] s_axi_wstrb,
    input  logic                    s_axi_wvalid,
    output logic                    s_axi_wready,

    output logic [1:0]              s_axi_bresp,
    output logic                    s_axi_bvalid,
    input  logic                    s_axi_bready,

    input  logic [ADDR_WIDTH-1:0]   s_axi_araddr,
    input  logic                    s_axi_arvalid,
    output logic                    s_axi_arready,

    output logic [DATA_WIDTH-1:0]   s_axi_rdata,
    output logic [1:0]              s_axi_rresp,
    output logic                    s_axi_rvalid,
    input  logic                    s_axi_rready,

    // Register access for IP core
    output logic [NUM_REGS-1:0][DATA_WIDTH-1:0] reg_out,
    input  logic [NUM_REGS-1:0][DATA_WIDTH-1:0] reg_in,
    output logic [NUM_REGS-1:0]                 reg_wr_en
);

    localparam logic [1:0] RESP_OKAY   = 2'b00;
    localparam logic [1:0] RESP_SLVERR = 2'b10;

    // Internal registers
    logic [DATA_WIDTH-1:0] registers [NUM_REGS];

    // Address decoding
    logic [$clog2(NUM_REGS)-1:0] wr_reg_idx, rd_reg_idx;
    logic                        wr_addr_valid, rd_addr_valid;

    assign wr_reg_idx   = s_axi_awaddr[$clog2(NUM_REGS)+1:2];
    assign rd_reg_idx   = s_axi_araddr[$clog2(NUM_REGS)+1:2];
    assign wr_addr_valid = (s_axi_awaddr[ADDR_WIDTH-1:$clog2(NUM_REGS)+2] == '0);
    assign rd_addr_valid = (s_axi_araddr[ADDR_WIDTH-1:$clog2(NUM_REGS)+2] == '0);

    // FSM for write channel
    typedef enum logic [1:0] {
        WR_IDLE,
        WR_DATA,
        WR_RESP
    } wr_state_e;

    wr_state_e wr_state;

    logic [ADDR_WIDTH-1:0] wr_addr_reg;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_state       <= WR_IDLE;
            s_axi_awready  <= 1'b0;
            s_axi_wready   <= 1'b0;
            s_axi_bvalid   <= 1'b0;
            s_axi_bresp    <= RESP_OKAY;
            wr_addr_reg    <= '0;
            reg_wr_en      <= '0;
        end else begin
            reg_wr_en <= '0;

            unique case (wr_state)
                WR_IDLE: begin
                    s_axi_awready <= 1'b1;
                    s_axi_wready  <= 1'b0;
                    s_axi_bvalid  <= 1'b0;
                    if (s_axi_awvalid && s_axi_awready) begin
                        wr_addr_reg   <= s_axi_awaddr;
                        s_axi_awready <= 1'b0;
                        s_axi_wready  <= 1'b1;
                        wr_state      <= WR_DATA;
                    end
                end

                WR_DATA: begin
                    if (s_axi_wvalid && s_axi_wready) begin
                        s_axi_wready <= 1'b0;
                        if (wr_addr_valid) begin
                            // Byte-lane write with strobe support
                            for (int i = 0; i < DATA_WIDTH/8; i++) begin
                                if (s_axi_wstrb[i])
                                    registers[wr_reg_idx][i*8 +: 8] <= s_axi_wdata[i*8 +: 8];
                            end
                            reg_wr_en[wr_reg_idx] <= 1'b1;
                            s_axi_bresp <= RESP_OKAY;
                        end else begin
                            s_axi_bresp <= RESP_SLVERR;
                        end
                        s_axi_bvalid <= 1'b1;
                        wr_state     <= WR_RESP;
                    end
                end

                WR_RESP: begin
                    if (s_axi_bvalid && s_axi_bready) begin
                        s_axi_bvalid <= 1'b0;
                        wr_state     <= WR_IDLE;
                    end
                end

                default: wr_state <= WR_IDLE;
            endcase
        end
    end

    // FSM for read channel
    typedef enum logic [1:0] {
        RD_IDLE,
        RD_DATA
    } rd_state_e;

    rd_state_e rd_state;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_state      <= RD_IDLE;
            s_axi_arready <= 1'b0;
            s_axi_rvalid  <= 1'b0;
            s_axi_rdata   <= '0;
            s_axi_rresp   <= RESP_OKAY;
        end else begin
            unique case (rd_state)
                RD_IDLE: begin
                    s_axi_arready <= 1'b1;
                    if (s_axi_arvalid && s_axi_arready) begin
                        s_axi_arready <= 1'b0;
                        if (rd_addr_valid) begin
                            s_axi_rdata <= registers[rd_reg_idx];
                            s_axi_rresp <= RESP_OKAY;
                        end else begin
                            s_axi_rdata <= '0;
                            s_axi_rresp <= RESP_SLVERR;
                        end
                        s_axi_rvalid <= 1'b1;
                        rd_state     <= RD_DATA;
                    end
                end

                RD_DATA: begin
                    if (s_axi_rvalid && s_axi_rready) begin
                        s_axi_rvalid <= 1'b0;
                        rd_state     <= RD_IDLE;
                    end
                end

                default: rd_state <= RD_IDLE;
            endcase
        end
    end

    // Drive output registers
    always_comb begin
        for (int i = 0; i < NUM_REGS; i++)
            reg_out[i] = registers[i];
    end

endmodule
