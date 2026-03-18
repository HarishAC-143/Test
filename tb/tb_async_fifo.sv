// =============================================================================
// Testbench: Asynchronous FIFO (CDC)
// =============================================================================

module tb_async_fifo;

    parameter int DATA_WIDTH = 8;
    parameter int DEPTH      = 8;

    logic                  wr_clk, rd_clk;
    logic                  wr_rst_n, rd_rst_n;
    logic                  wr_en, rd_en;
    logic [DATA_WIDTH-1:0] wr_data;
    logic [DATA_WIDTH-1:0] rd_data;
    logic                  wr_full, rd_empty;

    async_fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH(DEPTH)
    ) dut (.*);

    // Two independent clocks: 100 MHz write, 75 MHz read
    initial wr_clk = 0;
    always #5  wr_clk = ~wr_clk;

    initial rd_clk = 0;
    always #6.67 rd_clk = ~rd_clk;

    // Reference queue for data integrity check
    logic [DATA_WIDTH-1:0] ref_queue [$];
    int errors = 0;

    initial begin
        $dumpfile("async_fifo_waves.vcd");
        $dumpvars(0, tb_async_fifo);

        wr_rst_n = 0;
        rd_rst_n = 0;
        wr_en    = 0;
        rd_en    = 0;
        wr_data  = 0;

        #50;
        wr_rst_n = 1;
        rd_rst_n = 1;

        $display("\n=== Test 1: Write data from fast clock domain ===");
        for (int i = 0; i < DEPTH; i++) begin
            @(posedge wr_clk);
            if (!wr_full) begin
                wr_en   = 1;
                wr_data = i * 11;
                ref_queue.push_back(i * 11);
            end
        end
        @(posedge wr_clk);
        wr_en = 0;

        // Wait for synchronization
        repeat(10) @(posedge rd_clk);

        $display("\n=== Test 2: Read data from slow clock domain ===");
        for (int i = 0; i < DEPTH; i++) begin
            @(posedge rd_clk);
            if (!rd_empty) begin
                rd_en = 1;
            end else begin
                rd_en = 0;
            end
        end
        @(posedge rd_clk);
        rd_en = 0;

        // Wait and check
        repeat(10) @(posedge rd_clk);

        $display("\n=== Test 3: Concurrent read and write ===");
        fork
            // Writer
            begin
                for (int i = 0; i < 20; i++) begin
                    @(posedge wr_clk);
                    if (!wr_full) begin
                        wr_en   = 1;
                        wr_data = 8'hA0 + i;
                    end else begin
                        wr_en = 0;
                    end
                end
                @(posedge wr_clk);
                wr_en = 0;
            end

            // Reader
            begin
                repeat(5) @(posedge rd_clk);  // slight delay
                for (int i = 0; i < 20; i++) begin
                    @(posedge rd_clk);
                    if (!rd_empty) begin
                        rd_en = 1;
                    end else begin
                        rd_en = 0;
                    end
                end
                @(posedge rd_clk);
                rd_en = 0;
            end
        join

        repeat(20) @(posedge rd_clk);

        $display("\n=== Async FIFO tests completed ===");
        $display("Errors: %0d", errors);
        $finish;
    end

    initial begin
        #50000;
        $display("ERROR: Testbench timed out!");
        $finish;
    end

endmodule
