// SystemVerilog Interface for AXI4-Lite
// Demonstrates the power of interfaces to bundle related signals

interface axi_lite_if #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
)(
    input logic aclk,
    input logic aresetn
);

    // Write address channel
    logic [ADDR_WIDTH-1:0] awaddr;
    logic                  awvalid;
    logic                  awready;

    // Write data channel
    logic [DATA_WIDTH-1:0]     wdata;
    logic [DATA_WIDTH/8-1:0]   wstrb;
    logic                      wvalid;
    logic                      wready;

    // Write response channel
    logic [1:0]  bresp;
    logic        bvalid;
    logic        bready;

    // Read address channel
    logic [ADDR_WIDTH-1:0] araddr;
    logic                  arvalid;
    logic                  arready;

    // Read data channel
    logic [DATA_WIDTH-1:0] rdata;
    logic [1:0]            rresp;
    logic                  rvalid;
    logic                  rready;

    // Master modport
    modport master (
        input  aclk, aresetn,
        output awaddr, awvalid, input awready,
        output wdata, wstrb, wvalid, input wready,
        input  bresp, bvalid, output bready,
        output araddr, arvalid, input arready,
        input  rdata, rresp, rvalid, output rready
    );

    // Slave modport
    modport slave (
        input  aclk, aresetn,
        input  awaddr, awvalid, output awready,
        input  wdata, wstrb, wvalid, output wready,
        output bresp, bvalid, input bready,
        input  araddr, arvalid, output arready,
        output rdata, rresp, rvalid, input rready
    );

endinterface


// AXI4-Lite Slave (Simple Register Bank)
module axi_lite_register_bank #(
    parameter NUM_REGS   = 8,
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32
)(
    axi_lite_if.slave axi
);

    localparam REG_ADDR_BITS = $clog2(NUM_REGS) + 2;

    logic [DATA_WIDTH-1:0] registers [0:NUM_REGS-1];

    typedef enum logic [1:0] {
        WR_IDLE,
        WR_DATA,
        WR_RESP
    } wr_state_e;

    typedef enum logic [1:0] {
        RD_IDLE,
        RD_DATA
    } rd_state_e;

    wr_state_e wr_state;
    rd_state_e rd_state;

    logic [ADDR_WIDTH-1:0] wr_addr_reg, rd_addr_reg;

    // Write FSM
    always_ff @(posedge axi.aclk or negedge axi.aresetn) begin
        if (!axi.aresetn) begin
            wr_state    <= WR_IDLE;
            axi.awready <= 1'b0;
            axi.wready  <= 1'b0;
            axi.bvalid  <= 1'b0;
            axi.bresp   <= 2'b00;
            wr_addr_reg <= '0;
            for (int i = 0; i < NUM_REGS; i++)
                registers[i] <= '0;
        end else begin
            case (wr_state)
                WR_IDLE: begin
                    axi.awready <= 1'b1;
                    axi.wready  <= 1'b0;
                    axi.bvalid  <= 1'b0;
                    if (axi.awvalid && axi.awready) begin
                        wr_addr_reg <= axi.awaddr;
                        axi.awready <= 1'b0;
                        axi.wready  <= 1'b1;
                        wr_state    <= WR_DATA;
                    end
                end

                WR_DATA: begin
                    if (axi.wvalid && axi.wready) begin
                        for (int i = 0; i < DATA_WIDTH/8; i++) begin
                            if (axi.wstrb[i])
                                registers[wr_addr_reg[REG_ADDR_BITS-1:2]][i*8 +: 8] <= axi.wdata[i*8 +: 8];
                        end
                        axi.wready <= 1'b0;
                        axi.bvalid <= 1'b1;
                        axi.bresp  <= 2'b00;
                        wr_state   <= WR_RESP;
                    end
                end

                WR_RESP: begin
                    if (axi.bready && axi.bvalid) begin
                        axi.bvalid <= 1'b0;
                        wr_state   <= WR_IDLE;
                    end
                end

                default: wr_state <= WR_IDLE;
            endcase
        end
    end

    // Read FSM
    always_ff @(posedge axi.aclk or negedge axi.aresetn) begin
        if (!axi.aresetn) begin
            rd_state    <= RD_IDLE;
            axi.arready <= 1'b0;
            axi.rvalid  <= 1'b0;
            axi.rdata   <= '0;
            axi.rresp   <= 2'b00;
            rd_addr_reg <= '0;
        end else begin
            case (rd_state)
                RD_IDLE: begin
                    axi.arready <= 1'b1;
                    axi.rvalid  <= 1'b0;
                    if (axi.arvalid && axi.arready) begin
                        rd_addr_reg <= axi.araddr;
                        axi.arready <= 1'b0;
                        axi.rvalid  <= 1'b1;
                        axi.rdata   <= registers[axi.araddr[REG_ADDR_BITS-1:2]];
                        axi.rresp   <= 2'b00;
                        rd_state    <= RD_DATA;
                    end
                end

                RD_DATA: begin
                    if (axi.rready && axi.rvalid) begin
                        axi.rvalid <= 1'b0;
                        rd_state   <= RD_IDLE;
                    end
                end

                default: rd_state <= RD_IDLE;
            endcase
        end
    end

endmodule
