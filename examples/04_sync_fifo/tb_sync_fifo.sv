// Testbench for Synchronous FIFO

module tb_sync_fifo;

    localparam int DATA_WIDTH = 8;
    localparam int DEPTH      = 8;
    localparam int ADDR_WIDTH = $clog2(DEPTH);

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
    logic [ADDR_WIDTH:0]   fill_level;

    int error_count = 0;

    sync_fifo #(
        .DATA_WIDTH   (DATA_WIDTH),
        .DEPTH        (DEPTH),
        .ALMOST_FULL  (DEPTH - 2),
        .ALMOST_EMPTY (2)
    ) dut (.*);

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    task automatic write_fifo(input logic [DATA_WIDTH-1:0] data);
        @(posedge clk);
        wr_en   <= 1'b1;
        wr_data <= data;
        @(posedge clk);
        wr_en   <= 1'b0;
    endtask

    task automatic read_fifo();
        @(posedge clk);
        rd_en <= 1'b1;
        @(posedge clk);
        rd_en <= 1'b0;
    endtask

    initial begin
        $display("=== Synchronous FIFO Testbench ===");
        $display("");

        rst_n   = 0;
        wr_en   = 0;
        rd_en   = 0;
        wr_data = '0;

        repeat (3) @(posedge clk);
        rst_n = 1;
        @(posedge clk);

        // Test 1: Empty after reset
        $display("[Test 1] Empty after reset");
        if (empty !== 1'b1) begin
            $error("[FAIL] FIFO should be empty after reset");
            error_count++;
        end else begin
            $display("[PASS] FIFO is empty after reset");
        end

        // Test 2: Write and read back
        $display("[Test 2] Write and read single value");
        write_fifo(8'hAB);
        @(posedge clk);
        if (empty !== 1'b0) begin
            $error("[FAIL] FIFO should not be empty after write");
            error_count++;
        end
        if (fill_level !== 1) begin
            $error("[FAIL] Fill level should be 1, got %0d", fill_level);
            error_count++;
        end

        read_fifo();
        @(posedge clk);
        if (rd_data !== 8'hAB) begin
            $error("[FAIL] Read data mismatch: expected=0xAB, got=0x%02h", rd_data);
            error_count++;
        end else begin
            $display("[PASS] Read back correct value: 0x%02h", rd_data);
        end

        // Test 3: Fill to capacity
        $display("[Test 3] Fill FIFO to capacity");
        for (int i = 0; i < DEPTH; i++) begin
            write_fifo(i[DATA_WIDTH-1:0]);
        end
        @(posedge clk);
        if (full !== 1'b1) begin
            $error("[FAIL] FIFO should be full");
            error_count++;
        end else begin
            $display("[PASS] FIFO reports full at %0d entries", fill_level);
        end

        // Test 4: Attempt write when full (should be ignored)
        $display("[Test 4] Write attempt when full");
        write_fifo(8'hFF);
        @(posedge clk);
        if (fill_level !== DEPTH) begin
            $error("[FAIL] Fill level changed when writing to full FIFO");
            error_count++;
        end else begin
            $display("[PASS] Write to full FIFO correctly ignored");
        end

        // Test 5: Read all entries in order
        $display("[Test 5] Read all entries (FIFO ordering)");
        for (int i = 0; i < DEPTH; i++) begin
            read_fifo();
            @(posedge clk);
            if (rd_data !== i[DATA_WIDTH-1:0]) begin
                $error("[FAIL] Entry %0d: expected=0x%02h, got=0x%02h",
                       i, i[DATA_WIDTH-1:0], rd_data);
                error_count++;
            end
        end
        $display("[PASS] All entries read in correct FIFO order");

        @(posedge clk);
        if (empty !== 1'b1) begin
            $error("[FAIL] FIFO should be empty after reading all");
            error_count++;
        end else begin
            $display("[PASS] FIFO is empty after reading all entries");
        end

        // Test 6: Simultaneous read/write
        $display("[Test 6] Simultaneous read and write");
        write_fifo(8'h11);
        write_fifo(8'h22);
        @(posedge clk);
        // Simultaneous read and write
        wr_en   <= 1'b1;
        wr_data <= 8'h33;
        rd_en   <= 1'b1;
        @(posedge clk);
        wr_en <= 1'b0;
        rd_en <= 1'b0;
        @(posedge clk);
        $display("[PASS] Simultaneous read/write completed, fill_level=%0d", fill_level);

        // Test 7: Almost-full / Almost-empty flags
        $display("[Test 7] Almost-full and almost-empty flags");
        // Drain FIFO
        while (!empty) begin
            read_fifo();
            @(posedge clk);
        end
        // Write 2 entries (should trigger almost_empty)
        write_fifo(8'hAA);
        write_fifo(8'hBB);
        @(posedge clk);
        if (almost_empty !== 1'b1) begin
            $error("[FAIL] Almost-empty should be asserted");
            error_count++;
        end else begin
            $display("[PASS] Almost-empty flag works");
        end

        // Fill close to capacity
        for (int i = 0; i < DEPTH - 2; i++)
            write_fifo(i[DATA_WIDTH-1:0]);
        @(posedge clk);
        if (almost_full !== 1'b1) begin
            $error("[FAIL] Almost-full should be asserted");
            error_count++;
        end else begin
            $display("[PASS] Almost-full flag works");
        end

        $display("");
        if (error_count == 0)
            $display("ALL TESTS PASSED");
        else
            $display("%0d FAILURES DETECTED", error_count);

        $finish;
    end

endmodule
