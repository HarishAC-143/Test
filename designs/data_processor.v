// ============================================================
// Data Processor - Example RTL for SDC Tutorial
// ============================================================
// A multi-clock data processing design demonstrating:
//   - PLL-based clock generation
//   - Pipelined data path
//   - Clock domain crossing via async FIFO
//   - SPI slave interface
//   - External memory interface
// ============================================================

module data_processor (
    input  wire        CLK_50M,
    input  wire        RST_N,

    // SPI Slave Interface (external MCU controls configuration)
    input  wire        SPI_SCLK,
    input  wire        SPI_MOSI,
    output wire        SPI_MISO,
    input  wire        SPI_CS_N,

    // ADC Input Interface (source-synchronous)
    input  wire        ADC_CLK,
    input  wire [11:0] adc_data,
    input  wire        adc_valid,

    // Processed Data Output (synchronous to pll_100m)
    output reg  [15:0] proc_data_out,
    output reg         proc_valid_out,

    // External SRAM Interface
    output wire [17:0] sram_addr,
    inout  wire [15:0] sram_dq,
    output wire        sram_we_n,
    output wire        sram_oe_n,
    output wire        sram_ce_n,

    // Status
    output wire [7:0]  LED,
    input  wire [3:0]  DIP_SW
);

    // ========================================================
    // PLL Instance
    // ========================================================
    wire pll_100m;
    wire pll_200m;
    wire pll_25m;
    wire pll_locked;

    pll_core pll_inst (
        .inclk0 (CLK_50M),
        .c0     (pll_100m),   // 100 MHz - main processing
        .c1     (pll_200m),   // 200 MHz - fast compute
        .c2     (pll_25m),    // 25 MHz  - slow I/O
        .locked (pll_locked)
    );

    // ========================================================
    // Reset Synchronizer (per clock domain)
    // ========================================================
    reg [2:0] rst_sync_100m;
    wire      rst_100m_n = rst_sync_100m[2];

    always @(posedge pll_100m or negedge RST_N) begin
        if (!RST_N)
            rst_sync_100m <= 3'b000;
        else
            rst_sync_100m <= {rst_sync_100m[1:0], pll_locked};
    end

    reg [2:0] rst_sync_200m;
    wire      rst_200m_n = rst_sync_200m[2];

    always @(posedge pll_200m or negedge RST_N) begin
        if (!RST_N)
            rst_sync_200m <= 3'b000;
        else
            rst_sync_200m <= {rst_sync_200m[1:0], pll_locked};
    end

    // ========================================================
    // ADC Data Capture (ADC_CLK domain)
    // ========================================================
    reg [11:0] adc_captured;
    reg        adc_cap_valid;

    always @(posedge ADC_CLK or negedge RST_N) begin
        if (!RST_N) begin
            adc_captured  <= 12'd0;
            adc_cap_valid <= 1'b0;
        end else begin
            adc_captured  <= adc_data;
            adc_cap_valid <= adc_valid;
        end
    end

    // ========================================================
    // CDC: ADC_CLK -> pll_100m via Async FIFO
    // ========================================================
    wire [11:0] fifo_rd_data;
    wire        fifo_rd_valid;
    wire        fifo_empty;
    wire        fifo_full;

    async_fifo #(
        .DATA_WIDTH (12),
        .ADDR_WIDTH (4)
    ) adc_fifo (
        .wr_clk   (ADC_CLK),
        .wr_rst_n (RST_N),
        .wr_en    (adc_cap_valid & ~fifo_full),
        .wr_data  (adc_captured),
        .full     (fifo_full),

        .rd_clk   (pll_100m),
        .rd_rst_n (rst_100m_n),
        .rd_en    (~fifo_empty),
        .rd_data  (fifo_rd_data),
        .empty    (fifo_empty)
    );

    assign fifo_rd_valid = ~fifo_empty;

    // ========================================================
    // Processing Pipeline (pll_100m domain, 3 stages)
    // ========================================================

    // Stage 1: Sign extension and scaling
    reg [15:0] pipe_s1;
    reg        pipe_s1_valid;

    always @(posedge pll_100m or negedge rst_100m_n) begin
        if (!rst_100m_n) begin
            pipe_s1       <= 16'd0;
            pipe_s1_valid <= 1'b0;
        end else begin
            pipe_s1       <= {4'b0, fifo_rd_data};
            pipe_s1_valid <= fifo_rd_valid;
        end
    end

    // Stage 2: Apply gain from configuration register
    reg [15:0] pipe_s2;
    reg        pipe_s2_valid;
    reg [7:0]  config_gain;

    always @(posedge pll_100m or negedge rst_100m_n) begin
        if (!rst_100m_n) begin
            pipe_s2       <= 16'd0;
            pipe_s2_valid <= 1'b0;
        end else begin
            pipe_s2       <= pipe_s1 + {8'd0, config_gain};
            pipe_s2_valid <= pipe_s1_valid;
        end
    end

    // Stage 3: Output register
    always @(posedge pll_100m or negedge rst_100m_n) begin
        if (!rst_100m_n) begin
            proc_data_out  <= 16'd0;
            proc_valid_out <= 1'b0;
        end else begin
            proc_data_out  <= pipe_s2;
            proc_valid_out <= pipe_s2_valid;
        end
    end

    // ========================================================
    // Status LEDs (directly from slow registers, no timing req)
    // ========================================================
    assign LED = {pll_locked, ~fifo_full, ~fifo_empty, pipe_s2_valid,
                  DIP_SW};

endmodule
