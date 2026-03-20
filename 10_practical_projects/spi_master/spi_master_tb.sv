// Testbench for SPI master — loopback test (MOSI connected to MISO).

module spi_master_tb;

    localparam int DATA_WIDTH   = 8;
    localparam int CLK_DIV_BITS = 4;
    localparam int CLK_PERIOD   = 10;

    logic                    clk, rst_n;
    logic [CLK_DIV_BITS-1:0] clk_div;
    logic                    cpol, cpha, msb_first;
    logic                    start;
    logic [DATA_WIDTH-1:0]   tx_data, rx_data;
    logic                    busy, done;
    logic                    sclk, mosi, miso, cs_n;

    spi_master #(
        .DATA_WIDTH   (DATA_WIDTH),
        .CLK_DIV_BITS (CLK_DIV_BITS)
    ) dut (.*);

    // Loopback: MOSI -> MISO
    assign miso = mosi;

    initial clk = 1'b0;
    always #(CLK_PERIOD/2) clk = ~clk;

    int error_count = 0;

    task automatic spi_transfer(
        input logic [DATA_WIDTH-1:0] data,
        input logic                  t_cpol,
        input logic                  t_cpha,
        input string                 desc
    );
        cpol    = t_cpol;
        cpha    = t_cpha;
        tx_data = data;

        @(posedge clk);
        start = 1'b1;
        @(posedge clk);
        start = 1'b0;

        wait (done);
        @(posedge clk);

        if (rx_data === data) begin
            $display("PASS: %s — TX=0x%02h RX=0x%02h", desc, data, rx_data);
        end else begin
            $display("FAIL: %s — TX=0x%02h RX=0x%02h", desc, data, rx_data);
            error_count++;
        end

        repeat (5) @(posedge clk);
    endtask

    initial begin
        $display("=== SPI Master Testbench (loopback) ===\n");

        rst_n     = 1'b0;
        start     = 1'b0;
        tx_data   = '0;
        clk_div   = 4'd2;
        cpol      = 1'b0;
        cpha      = 1'b0;
        msb_first = 1'b1;

        repeat (5) @(posedge clk);
        rst_n = 1'b1;
        repeat (3) @(posedge clk);

        // Test all 4 SPI modes
        spi_transfer(8'hA5, 1'b0, 1'b0, "Mode 0 (CPOL=0,CPHA=0)");
        spi_transfer(8'h5A, 1'b0, 1'b1, "Mode 1 (CPOL=0,CPHA=1)");
        spi_transfer(8'hFF, 1'b1, 1'b0, "Mode 2 (CPOL=1,CPHA=0)");
        spi_transfer(8'h81, 1'b1, 1'b1, "Mode 3 (CPOL=1,CPHA=1)");

        // Various data patterns
        spi_transfer(8'h00, 1'b0, 1'b0, "All zeros");
        spi_transfer(8'hFF, 1'b0, 1'b0, "All ones");
        spi_transfer(8'h55, 1'b0, 1'b0, "Alternating 01");
        spi_transfer(8'hAA, 1'b0, 1'b0, "Alternating 10");

        $display("\nResults: %0d errors", error_count);
        if (error_count == 0)
            $display("*** ALL TESTS PASSED ***");
        $finish;
    end

    initial begin
        $dumpfile("spi_master.vcd");
        $dumpvars(0, spi_master_tb);
    end

endmodule
