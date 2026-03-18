// =============================================================================
// Testbench: SPI Master Controller
// =============================================================================

module tb_spi_master;

    parameter int DATA_WIDTH = 8;
    parameter int CLK_DIV    = 4;

    logic                  clk;
    logic                  rst_n;
    logic                  start;
    logic [DATA_WIDTH-1:0] tx_data;
    logic [DATA_WIDTH-1:0] rx_data;
    logic                  busy;
    logic                  done;
    logic                  cpol;
    logic                  cpha;
    logic                  sclk;
    logic                  mosi;
    logic                  miso;
    logic                  cs_n;

    spi_master #(
        .DATA_WIDTH(DATA_WIDTH),
        .CLK_DIV(CLK_DIV)
    ) dut (.*);

    initial clk = 0;
    always #5 clk = ~clk;

    // Simple SPI slave model: echoes back inverted data
    logic [DATA_WIDTH-1:0] slave_shift_reg;
    logic [2:0] slave_bit_cnt;

    always @(negedge cs_n) begin
        slave_shift_reg = 8'hA5;  // Slave sends 0xA5
        slave_bit_cnt   = 0;
    end

    assign miso = cs_n ? 1'bz : slave_shift_reg[DATA_WIDTH-1];

    always @(posedge sclk) begin
        if (!cs_n) begin
            slave_shift_reg = {slave_shift_reg[DATA_WIDTH-2:0], mosi};
            slave_bit_cnt   = slave_bit_cnt + 1;
        end
    end

    task automatic spi_transfer(
        input logic [DATA_WIDTH-1:0] data,
        input logic pol,
        input logic pha
    );
        @(posedge clk);
        cpol    = pol;
        cpha    = pha;
        tx_data = data;
        start   = 1;
        @(posedge clk);
        start = 0;

        // Wait for completion
        wait(done);
        @(posedge clk);
        $display("  TX=0x%02h RX=0x%02h (CPOL=%0b CPHA=%0b)", data, rx_data, pol, pha);
    endtask

    initial begin
        $dumpfile("spi_waves.vcd");
        $dumpvars(0, tb_spi_master);

        rst_n   = 0;
        start   = 0;
        tx_data = 0;
        cpol    = 0;
        cpha    = 0;

        repeat(5) @(posedge clk);
        rst_n = 1;
        repeat(2) @(posedge clk);

        $display("\n=== Test 1: SPI Mode 0 (CPOL=0, CPHA=0) ===");
        spi_transfer(8'h55, 0, 0);

        $display("\n=== Test 2: SPI Mode 1 (CPOL=0, CPHA=1) ===");
        spi_transfer(8'hAA, 0, 1);

        $display("\n=== Test 3: SPI Mode 2 (CPOL=1, CPHA=0) ===");
        spi_transfer(8'h3C, 1, 0);

        $display("\n=== Test 4: SPI Mode 3 (CPOL=1, CPHA=1) ===");
        spi_transfer(8'hF0, 1, 1);

        $display("\n=== Test 5: Back-to-back transfers ===");
        for (int i = 0; i < 4; i++) begin
            spi_transfer(i * 16 + 1, 0, 0);
        end

        repeat(10) @(posedge clk);
        $display("\n=== All SPI tests completed ===");
        $finish;
    end

    initial begin
        #100000;
        $display("ERROR: Testbench timed out!");
        $finish;
    end

endmodule
