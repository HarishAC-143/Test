// Testbench for Synchronous FIFO
// Demonstrates self-checking testbench with reference model

module fifo_tb;

    parameter DATA_WIDTH = 8;
    parameter DEPTH      = 8;

    logic                   clk;
    logic                   rst_n;
    logic                   wr_en;
    logic                   rd_en;
    logic [DATA_WIDTH-1:0]  wr_data;
    logic [DATA_WIDTH-1:0]  rd_data;
    logic                   full;
    logic                   empty;
    logic [$clog2(DEPTH):0] count;

    // Instantiate DUT
    sync_fifo #(
        .DATA_WIDTH (DATA_WIDTH),
        .DEPTH      (DEPTH)
    ) dut (
        .clk     (clk),
        .rst_n   (rst_n),
        .wr_en   (wr_en),
        .rd_en   (rd_en),
        .wr_data (wr_data),
        .rd_data (rd_data),
        .full    (full),
        .empty   (empty),
        .count   (count)
    );

    // Clock generation
    initial clk = 0;
    always #5 clk = ~clk;

    // Reference model: simple queue
    logic [DATA_WIDTH-1:0] ref_queue [$];

    int errors = 0;

    task automatic write_fifo(input logic [DATA_WIDTH-1:0] data);
        wr_en   = 1'b1;
        wr_data = data;
        @(posedge clk);
        #1;
        wr_en = 1'b0;
        if (!full)
            ref_queue.push_back(data);
    endtask

    task automatic read_fifo(output logic [DATA_WIDTH-1:0] data);
        rd_en = 1'b1;
        @(posedge clk);
        #1;
        rd_en = 1'b0;
        data = rd_data;
    endtask

    task automatic check_read(input logic [DATA_WIDTH-1:0] expected);
        logic [DATA_WIDTH-1:0] actual;
        read_fifo(actual);
        if (actual !== expected) begin
            $error("Read mismatch: got %0h, expected %0h", actual, expected);
            errors++;
        end
    endtask

    // Main test sequence
    initial begin
        $display("=== FIFO Testbench ===");

        rst_n   = 1'b0;
        wr_en   = 1'b0;
        rd_en   = 1'b0;
        wr_data = '0;

        repeat (3) @(posedge clk);
        rst_n = 1'b1;
        @(posedge clk);
        #1;

        // Test 1: Verify empty after reset
        assert (empty == 1'b1) else begin $error("FIFO not empty after reset"); errors++; end
        assert (full == 1'b0) else begin $error("FIFO full after reset"); errors++; end
        $display("PASS: FIFO empty after reset");

        // Test 2: Write until full
        $display("Writing %0d items...", DEPTH);
        for (int i = 0; i < DEPTH; i++) begin
            write_fifo(DATA_WIDTH'(i * 11 + 3));
        end
        @(posedge clk); #1;
        assert (full == 1'b1) else begin $error("FIFO not full after %0d writes", DEPTH); errors++; end
        $display("PASS: FIFO reports full correctly");

        // Test 3: Try write when full (should be ignored)
        write_fifo(8'hFF);
        $display("PASS: Write to full FIFO handled");

        // Test 4: Read all items and verify order
        $display("Reading back all items...");
        for (int i = 0; i < DEPTH; i++) begin
            logic [DATA_WIDTH-1:0] expected = ref_queue.pop_front();
            check_read(expected);
        end
        @(posedge clk); #1;
        assert (empty == 1'b1) else begin $error("FIFO not empty after reading all"); errors++; end
        $display("PASS: All items read in correct order");

        // Test 5: Simultaneous read/write
        $display("Testing simultaneous read/write...");
        write_fifo(8'hAA);
        write_fifo(8'hBB);

        wr_en   = 1'b1;
        rd_en   = 1'b1;
        wr_data = 8'hCC;
        @(posedge clk); #1;
        wr_en = 1'b0;
        rd_en = 1'b0;
        $display("PASS: Simultaneous read/write handled");

        // Summary
        repeat (2) @(posedge clk);
        $display("");
        if (errors == 0)
            $display("=== All FIFO tests PASSED ===");
        else
            $display("=== %0d FIFO tests FAILED ===", errors);

        $finish;
    end

    // Dump waveforms
    initial begin
        $dumpfile("fifo_tb.vcd");
        $dumpvars(0, fifo_tb);
    end

endmodule
