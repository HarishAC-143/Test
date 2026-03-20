// Testbench for asynchronous FIFO.
// Uses different clock frequencies for write and read domains.

module async_fifo_tb;

    localparam int DATA_WIDTH = 8;
    localparam int DEPTH      = 8;

    // Clocks with different periods
    localparam int WR_CLK_PERIOD = 10;  // 100 MHz
    localparam int RD_CLK_PERIOD = 14;  // ~71 MHz

    logic                  wr_clk, rd_clk;
    logic                  wr_rst_n, rd_rst_n;
    logic                  wr_en, rd_en;
    logic [DATA_WIDTH-1:0] wr_data, rd_data;
    logic                  full, empty;

    async_fifo #(
        .DATA_WIDTH (DATA_WIDTH),
        .DEPTH      (DEPTH)
    ) dut (.*);

    // Clock generation
    initial wr_clk = 1'b0;
    always #(WR_CLK_PERIOD/2) wr_clk = ~wr_clk;

    initial rd_clk = 1'b0;
    always #(RD_CLK_PERIOD/2) rd_clk = ~rd_clk;

    // Reference model
    logic [DATA_WIDTH-1:0] expected_queue [$];
    int error_count = 0;

    initial begin
        $display("=== Async FIFO Testbench ===");
        $display("Write clk: %0d ns period, Read clk: %0d ns period",
                 WR_CLK_PERIOD, RD_CLK_PERIOD);

        wr_rst_n = 1'b0;
        rd_rst_n = 1'b0;
        wr_en    = 1'b0;
        rd_en    = 1'b0;
        wr_data  = '0;

        #(WR_CLK_PERIOD * 5);
        wr_rst_n = 1'b1;
        rd_rst_n = 1'b1;
        #(WR_CLK_PERIOD * 3);

        // Test 1: Write several entries from write domain
        $display("\n--- Test 1: Sequential write then read ---");
        for (int i = 0; i < DEPTH; i++) begin
            @(posedge wr_clk);
            wr_en   = 1'b1;
            wr_data = DATA_WIDTH'(i + 10);
            expected_queue.push_back(DATA_WIDTH'(i + 10));
        end
        @(posedge wr_clk);
        wr_en = 1'b0;

        // Wait for synchronizer latency
        #(RD_CLK_PERIOD * 4);

        // Read all entries from read domain
        for (int i = 0; i < DEPTH; i++) begin
            @(posedge rd_clk);
            rd_en = 1'b1;
            @(posedge rd_clk);
            rd_en = 1'b0;

            logic [DATA_WIDTH-1:0] expected;
            expected = expected_queue.pop_front();
            if (rd_data !== expected) begin
                $display("FAIL: read 0x%02h, expected 0x%02h", rd_data, expected);
                error_count++;
            end else begin
                $display("PASS: read 0x%02h", rd_data);
            end
            @(posedge rd_clk);
        end

        // Test 2: Concurrent write and read
        $display("\n--- Test 2: Concurrent write and read ---");
        fork
            begin : writer
                for (int i = 0; i < 20; i++) begin
                    @(posedge wr_clk);
                    if (!full) begin
                        wr_en   = 1'b1;
                        wr_data = DATA_WIDTH'(i + 100);
                        expected_queue.push_back(DATA_WIDTH'(i + 100));
                    end else begin
                        wr_en = 1'b0;
                        i--;
                    end
                end
                @(posedge wr_clk);
                wr_en = 1'b0;
            end

            begin : reader
                #(RD_CLK_PERIOD * 4);
                for (int i = 0; i < 20; i++) begin
                    @(posedge rd_clk);
                    if (!empty) begin
                        rd_en = 1'b1;
                        @(posedge rd_clk);
                        rd_en = 1'b0;

                        logic [DATA_WIDTH-1:0] exp;
                        exp = expected_queue.pop_front();
                        if (rd_data !== exp) begin
                            $display("FAIL: concurrent read 0x%02h, expected 0x%02h",
                                     rd_data, exp);
                            error_count++;
                        end
                    end else begin
                        rd_en = 1'b0;
                        i--;
                    end
                    @(posedge rd_clk);
                end
            end
        join

        #(RD_CLK_PERIOD * 10);

        if (error_count == 0)
            $display("\n*** ALL TESTS PASSED ***");
        else
            $display("\n*** %0d TESTS FAILED ***", error_count);

        $finish;
    end

    initial begin
        $dumpfile("async_fifo.vcd");
        $dumpvars(0, async_fifo_tb);
    end

endmodule
