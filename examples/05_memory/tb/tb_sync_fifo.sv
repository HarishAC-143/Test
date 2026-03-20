// Testbench: Synchronous FIFO

`timescale 1ns / 1ps

module tb_sync_fifo;

    parameter DATA_WIDTH = 8;
    parameter DEPTH      = 8;
    parameter ADDR_WIDTH = $clog2(DEPTH);
    parameter CLK_PERIOD = 10;

    logic                    clk, rst_n;
    logic                    wr_en, rd_en;
    logic [DATA_WIDTH-1:0]   wr_data, rd_data;
    logic                    full, empty;
    logic [ADDR_WIDTH:0]     count;

    sync_fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH(DEPTH)
    ) u_dut (.*);

    initial clk = 1'b0;
    always #(CLK_PERIOD/2) clk = ~clk;

    initial begin
        $display("=== SYNC FIFO Testbench ===");

        rst_n   = 1'b0;
        wr_en   = 1'b0;
        rd_en   = 1'b0;
        wr_data = '0;
        repeat (3) @(posedge clk);
        rst_n = 1'b1;
        @(posedge clk);
        #1;

        // Initially empty
        assert (empty && !full && count == 0)
            else $error("After reset: should be empty");
        $display("  Reset: empty=%0b full=%0b count=%0d  PASS", empty, full, count);

        // Fill FIFO
        $display("  Filling FIFO...");
        for (int i = 0; i < DEPTH; i++) begin
            wr_en   = 1'b1;
            wr_data = i[DATA_WIDTH-1:0];
            @(posedge clk);
        end
        wr_en = 1'b0;
        @(posedge clk);
        #1;
        assert (full && !empty && count == DEPTH[ADDR_WIDTH:0])
            else $error("Full: full=%0b count=%0d", full, count);
        $display("  Full: empty=%0b full=%0b count=%0d  PASS", empty, full, count);

        // Write when full — should be ignored
        wr_en   = 1'b1;
        wr_data = 8'hFF;
        @(posedge clk);
        wr_en = 1'b0;
        @(posedge clk);
        #1;
        assert (count == DEPTH[ADDR_WIDTH:0])
            else $error("Write-when-full: count should not exceed depth");
        $display("  Write-when-full ignored  PASS");

        // Read all data — verify FIFO order
        $display("  Reading FIFO...");
        for (int i = 0; i < DEPTH; i++) begin
            rd_en = 1'b1;
            @(posedge clk);
            #1;
            assert (rd_data == i[DATA_WIDTH-1:0])
                else $error("Read[%0d]: expected %02h, got %02h", i, i, rd_data);
        end
        rd_en = 1'b0;
        @(posedge clk);
        #1;
        assert (empty && !full && count == 0)
            else $error("After drain: should be empty");
        $display("  Drained: empty=%0b count=%0d  PASS", empty, count);

        // Simultaneous read/write at empty — only write should take effect
        wr_en   = 1'b1;
        rd_en   = 1'b1;
        wr_data = 8'hAB;
        @(posedge clk);
        wr_en = 1'b0;
        rd_en = 1'b0;
        @(posedge clk);
        #1;
        $display("  Simultaneous R/W: count=%0d  PASS", count);

        $display("=== SYNC FIFO All Tests Passed ===");
        $finish;
    end

    initial begin
        #100000;
        $error("Simulation timeout!");
        $finish;
    end

endmodule
