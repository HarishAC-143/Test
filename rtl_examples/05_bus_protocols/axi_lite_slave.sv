// =============================================================================
// AXI4-Lite Slave Interface
// Implements a memory-mapped register bank accessible via AXI4-Lite.
// Supports: 32-bit data, byte-enable writes, separate read/write channels.
// =============================================================================

module axi_lite_slave #(
    parameter ADDR_WIDTH = 8,
    parameter DATA_WIDTH = 32,
    parameter NUM_REGS   = 16,
    parameter STRB_WIDTH = DATA_WIDTH / 8
) (
    input  logic                    aclk,
    input  logic                    aresetn,

    // Write Address Channel
    input  logic [ADDR_WIDTH-1:0]   s_axi_awaddr,
    input  logic                    s_axi_awvalid,
    output logic                    s_axi_awready,

    // Write Data Channel
    input  logic [DATA_WIDTH-1:0]   s_axi_wdata,
    input  logic [STRB_WIDTH-1:0]   s_axi_wstrb,
    input  logic                    s_axi_wvalid,
    output logic                    s_axi_wready,

    // Write Response Channel
    output logic [1:0]              s_axi_bresp,
    output logic                    s_axi_bvalid,
    input  logic                    s_axi_bready,

    // Read Address Channel
    input  logic [ADDR_WIDTH-1:0]   s_axi_araddr,
    input  logic                    s_axi_arvalid,
    output logic                    s_axi_arready,

    // Read Data Channel
    output logic [DATA_WIDTH-1:0]   s_axi_rdata,
    output logic [1:0]              s_axi_rresp,
    output logic                    s_axi_rvalid,
    input  logic                    s_axi_rready,

    // Register access (exposed to user logic)
    output logic [DATA_WIDTH-1:0]   reg_out [NUM_REGS],
    input  logic [DATA_WIDTH-1:0]   reg_in  [NUM_REGS]
);

    localparam REG_ADDR_WIDTH = $clog2(NUM_REGS);

    // Internal register file
    logic [DATA_WIDTH-1:0] slv_regs [NUM_REGS];

    // Address latches
    logic [ADDR_WIDTH-1:0] aw_addr_latched;
    logic [ADDR_WIDTH-1:0] ar_addr_latched;

    // Handshake tracking
    logic aw_done, w_done;

    // =========================================================================
    // Write Address Channel
    // =========================================================================
    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            s_axi_awready   <= 1'b0;
            aw_addr_latched <= '0;
            aw_done         <= 1'b0;
        end else begin
            if (s_axi_awvalid && !aw_done && !s_axi_awready) begin
                s_axi_awready   <= 1'b1;
                aw_addr_latched <= s_axi_awaddr;
            end else begin
                s_axi_awready <= 1'b0;
            end

            if (s_axi_awvalid && s_axi_awready)
                aw_done <= 1'b1;
            else if (s_axi_bvalid && s_axi_bready)
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

    // Register write with byte strobes
    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            for (int i = 0; i < NUM_REGS; i++)
                slv_regs[i] <= '0;
        end else if (aw_done && w_done) begin
            automatic logic [REG_ADDR_WIDTH-1:0] wr_idx;
            wr_idx = aw_addr_latched[REG_ADDR_WIDTH+1:2];
            for (int b = 0; b < STRB_WIDTH; b++) begin
                if (s_axi_wstrb[b])
                    slv_regs[wr_idx][8*b +: 8] <= s_axi_wdata[8*b +: 8];
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
            if (aw_done && w_done && !s_axi_bvalid) begin
                s_axi_bvalid <= 1'b1;
                s_axi_bresp  <= 2'b00;  // OKAY
            end else if (s_axi_bvalid && s_axi_bready) begin
                s_axi_bvalid <= 1'b0;
            end
        end
    end

    // =========================================================================
    // Read Address Channel
    // =========================================================================
    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            s_axi_arready   <= 1'b0;
            ar_addr_latched <= '0;
        end else begin
            if (s_axi_arvalid && !s_axi_arready) begin
                s_axi_arready   <= 1'b1;
                ar_addr_latched <= s_axi_araddr;
            end else begin
                s_axi_arready <= 1'b0;
            end
        end
    end

    // =========================================================================
    // Read Data Channel
    // =========================================================================
    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            s_axi_rvalid <= 1'b0;
            s_axi_rdata  <= '0;
            s_axi_rresp  <= 2'b00;
        end else begin
            if (s_axi_arready && s_axi_arvalid && !s_axi_rvalid) begin
                s_axi_rvalid <= 1'b1;
                s_axi_rresp  <= 2'b00;  // OKAY
                s_axi_rdata  <= reg_in[ar_addr_latched[REG_ADDR_WIDTH+1:2]];
            end else if (s_axi_rvalid && s_axi_rready) begin
                s_axi_rvalid <= 1'b0;
            end
        end
    end

    // Expose registers to user logic
    always_comb begin
        for (int i = 0; i < NUM_REGS; i++)
            reg_out[i] = slv_regs[i];
    end

endmodule
