// =============================================================================
// Testbench: Parameterized Synchronous FIFO
// =============================================================================

module tb_parameterized_fifo;

    parameter int DATA_WIDTH = 8;
    parameter int DEPTH      = 8;

    logic                  clk;
    logic                  rst_n;
    logic                  wr_en;
    logic [DATA_WIDTH-1:0] wr_data;
    logic                  rd_en;
    logic [DATA_WIDTH-1:0] rd_data;
    logic                  full;
    logic                  empty;
    logic                  almost_full;
    logic                  almost_empty;
    logic [$clog2(DEPTH):0] count;

    parameterized_fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH(DEPTH),
        .ALMOST_FULL_THRESH(DEPTH - 2),
        .ALMOST_EMPTY_THRESH(2)
    ) dut (.*);

    // Clock generation
    initial clk = 0;
    always #5 clk = ~clk;

    // Test sequence
    initial begin
        $dumpfile("fifo_waves.vcd");
        $dumpvars(0, tb_parameterized_fifo);

        rst_n   = 0;
        wr_en   = 0;
        rd_en   = 0;
        wr_data = 0;

        repeat(5) @(posedge clk);
        rst_n = 1;

        $display("\n=== Test 1: Write until full ===");
        for (int i = 0; i < DEPTH; i++) begin
            @(posedge clk);
            wr_en   = 1;
            wr_data = i * 10;
        end
        @(posedge clk);
        wr_en = 0;

        $display("Full=%0b, Count=%0d", full, count);
        assert(full == 1) else $error("FIFO should be full!");
        assert(count == DEPTH) else $error("Count should be %0d", DEPTH);

        $display("\n=== Test 2: Read all data ===");
        for (int i = 0; i < DEPTH; i++) begin
            @(posedge clk);
            rd_en = 1;
        end
        @(posedge clk);
        rd_en = 0;

        @(posedge clk);
        $display("Empty=%0b, Count=%0d", empty, count);
        assert(empty == 1) else $error("FIFO should be empty!");

        $display("\n=== Test 3: Simultaneous read/write ===");
        // Fill half
        for (int i = 0; i < DEPTH/2; i++) begin
            @(posedge clk);
            wr_en   = 1;
            wr_data = 8'hA0 + i;
        end
        @(posedge clk);
        // Simultaneous operations
        for (int i = 0; i < 10; i++) begin
            @(posedge clk);
            wr_en   = 1;
            rd_en   = 1;
            wr_data = 8'hF0 + i;
        end
        @(posedge clk);
        wr_en = 0;
        rd_en = 0;

        $display("Count after simultaneous R/W: %0d", count);

        $display("\n=== Test 4: Almost full/empty thresholds ===");
        // Drain FIFO first
        while (!empty) begin
            @(posedge clk);
            rd_en = 1;
        end
        @(posedge clk);
        rd_en = 0;

        // Write 2 entries — should trigger almost_empty
        @(posedge clk);
        wr_en = 1; wr_data = 8'h11;
        @(posedge clk);
        wr_data = 8'h22;
        @(posedge clk);
        wr_en = 0;
        @(posedge clk);
        $display("Almost_empty=%0b (expected 1)", almost_empty);

        repeat(5) @(posedge clk);
        $display("\n=== All FIFO tests completed ===");
        $finish;
    end

    // Timeout watchdog
    initial begin
        #10000;
        $display("ERROR: Testbench timed out!");
        $finish;
    end

endmodule
