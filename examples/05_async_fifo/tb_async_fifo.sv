// Testbench for Asynchronous FIFO
// Uses two independent clocks to verify CDC behavior

module tb_async_fifo;

    localparam int DATA_WIDTH = 8;
    localparam int DEPTH      = 8;

    logic                  wr_clk, rd_clk;
    logic                  wr_rst_n, rd_rst_n;
    logic                  wr_en, rd_en;
    logic [DATA_WIDTH-1:0] wr_data;
    logic [DATA_WIDTH-1:0] rd_data;
    logic                  wr_full, rd_empty;

    int error_count = 0;
    int wr_count = 0;
    int rd_count = 0;
    logic [DATA_WIDTH-1:0] rd_expected[$];

    async_fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH(DEPTH)
    ) dut (.*);

    // Write clock: 100 MHz (10 ns period)
    initial begin
        wr_clk = 0;
        forever #5 wr_clk = ~wr_clk;
    end

    // Read clock: 73 MHz (13.7 ns period) — intentionally asynchronous
    initial begin
        rd_clk = 0;
        forever #6.85 rd_clk = ~rd_clk;
    end

    initial begin
        $display("=== Asynchronous FIFO Testbench ===");
        $display("Write clock: 100 MHz, Read clock: ~73 MHz");
        $display("");

        wr_rst_n = 0;
        rd_rst_n = 0;
        wr_en    = 0;
        rd_en    = 0;
        wr_data  = '0;

        #50;
        wr_rst_n = 1;
        rd_rst_n = 1;
        #20;

        // Test 1: Write data from write domain
        $display("[Test 1] Write 8 items (fill FIFO)");
        for (int i = 0; i < DEPTH; i++) begin
            @(posedge wr_clk);
            wr_en   = 1;
            wr_data = i[DATA_WIDTH-1:0];
            rd_expected.push_back(i[DATA_WIDTH-1:0]);
            wr_count++;
            @(posedge wr_clk);
            wr_en = 0;
            #2; // Small delay for synchronizer
        end
        $display("  Wrote %0d items", wr_count);

        // Allow synchronizers to propagate
        repeat (5) @(posedge wr_clk);

        if (wr_full) begin
            $display("[PASS] FIFO reports full after %0d writes", wr_count);
        end else begin
            $error("[FAIL] FIFO should be full");
            error_count++;
        end

        // Test 2: Read data from read domain and verify order
        $display("");
        $display("[Test 2] Read all items and verify order");
        repeat (3) @(posedge rd_clk);

        for (int i = 0; i < DEPTH; i++) begin
            @(posedge rd_clk);
            if (!rd_empty) begin
                rd_en = 1;
                @(posedge rd_clk);
                rd_en = 0;

                if (rd_expected.size() > 0) begin
                    automatic logic [DATA_WIDTH-1:0] exp = rd_expected.pop_front();
                    rd_count++;
                    if (rd_data !== exp) begin
                        $error("[FAIL] Read %0d: expected=0x%02h, got=0x%02h",
                               rd_count, exp, rd_data);
                        error_count++;
                    end
                end
                repeat (2) @(posedge rd_clk);
            end
        end
        $display("  Read %0d items correctly", rd_count);

        // Allow synchronizers
        repeat (5) @(posedge rd_clk);

        if (rd_empty) begin
            $display("[PASS] FIFO reports empty after reading all");
        end else begin
            $error("[FAIL] FIFO should be empty");
            error_count++;
        end

        // Test 3: Concurrent read/write with different clock rates
        $display("");
        $display("[Test 3] Concurrent read/write stress test");
        fork
            // Writer: send 20 items
            begin
                for (int i = 0; i < 20; i++) begin
                    @(posedge wr_clk);
                    while (wr_full) @(posedge wr_clk);
                    wr_en   = 1;
                    wr_data = (i + 100) & 8'hFF;
                    @(posedge wr_clk);
                    wr_en = 0;
                    repeat ($urandom_range(0, 3)) @(posedge wr_clk);
                end
            end

            // Reader: consume items
            begin
                for (int i = 0; i < 20; i++) begin
                    @(posedge rd_clk);
                    while (rd_empty) @(posedge rd_clk);
                    rd_en = 1;
                    @(posedge rd_clk);
                    rd_en = 0;
                    repeat ($urandom_range(0, 3)) @(posedge rd_clk);
                end
            end
        join
        $display("[PASS] Concurrent stress test completed without deadlock");

        #100;
        $display("");
        if (error_count == 0)
            $display("ALL TESTS PASSED");
        else
            $display("%0d FAILURES DETECTED", error_count);

        $finish;
    end

    // Timeout watchdog
    initial begin
        #100_000;
        $error("TIMEOUT: Simulation took too long");
        $finish;
    end

endmodule
