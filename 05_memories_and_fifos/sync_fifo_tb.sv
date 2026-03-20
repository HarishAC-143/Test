// Self-checking synchronous FIFO testbench.

module sync_fifo_tb;

    localparam int DATA_WIDTH = 8;
    localparam int DEPTH      = 8;
    localparam int CLK_PERIOD = 10;

    logic                  clk, rst_n;
    logic                  wr_en, rd_en;
    logic [DATA_WIDTH-1:0] wr_data, rd_data;
    logic                  full, empty;
    logic [$clog2(DEPTH):0] count;

    sync_fifo #(
        .DATA_WIDTH (DATA_WIDTH),
        .DEPTH      (DEPTH)
    ) dut (.*);

    initial clk = 1'b0;
    always #(CLK_PERIOD/2) clk = ~clk;

    int error_count = 0;

    // Reference model
    logic [DATA_WIDTH-1:0] ref_queue [$];

    task automatic write_fifo(input logic [DATA_WIDTH-1:0] data);
        wr_en   = 1'b1;
        wr_data = data;
        @(posedge clk);
        wr_en = 1'b0;
        ref_queue.push_back(data);
    endtask

    task automatic read_and_check();
        logic [DATA_WIDTH-1:0] expected;
        rd_en = 1'b1;
        @(posedge clk);
        rd_en = 1'b0;

        expected = ref_queue.pop_front();
        if (rd_data !== expected) begin
            $display("FAIL: read 0x%02h, expected 0x%02h", rd_data, expected);
            error_count++;
        end
    endtask

    initial begin
        $display("=== Sync FIFO Testbench (WIDTH=%0d, DEPTH=%0d) ===", DATA_WIDTH, DEPTH);

        rst_n   = 1'b0;
        wr_en   = 1'b0;
        rd_en   = 1'b0;
        wr_data = '0;
        repeat (3) @(posedge clk);
        rst_n = 1'b1;
        @(posedge clk);

        // Verify empty after reset
        if (!empty) begin
            $display("FAIL: FIFO not empty after reset");
            error_count++;
        end

        // Fill FIFO to full
        $display("Filling FIFO...");
        for (int i = 0; i < DEPTH; i++)
            write_fifo(DATA_WIDTH'(i * 17 + 3));

        @(posedge clk);
        if (!full) begin
            $display("FAIL: FIFO not full after %0d writes", DEPTH);
            error_count++;
        end
        $display("Count after fill: %0d", count);

        // Read all entries and verify order
        $display("Draining FIFO...");
        for (int i = 0; i < DEPTH; i++)
            read_and_check();

        @(posedge clk);
        if (!empty) begin
            $display("FAIL: FIFO not empty after draining");
            error_count++;
        end

        // Simultaneous read/write test
        $display("Simultaneous read/write...");
        for (int i = 0; i < 4; i++)
            write_fifo(DATA_WIDTH'(i + 100));

        for (int i = 0; i < 20; i++) begin
            wr_en   = 1'b1;
            wr_data = DATA_WIDTH'(i + 200);
            rd_en   = 1'b1;
            @(posedge clk);
            wr_en = 1'b0;
            rd_en = 1'b0;

            logic [DATA_WIDTH-1:0] expected;
            expected = ref_queue.pop_front();
            ref_queue.push_back(DATA_WIDTH'(i + 200));

            if (rd_data !== expected) begin
                $display("FAIL: sim R/W — read 0x%02h, expected 0x%02h", rd_data, expected);
                error_count++;
            end
        end

        // Drain remaining
        while (!empty)
            read_and_check();

        if (error_count == 0)
            $display("\n*** ALL TESTS PASSED ***");
        else
            $display("\n*** %0d TESTS FAILED ***", error_count);

        $finish;
    end

    initial begin
        $dumpfile("sync_fifo.vcd");
        $dumpvars(0, sync_fifo_tb);
    end

endmodule
