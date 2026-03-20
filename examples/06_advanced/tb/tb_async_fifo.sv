// Testbench: Asynchronous FIFO

`timescale 1ns / 1ps

module tb_async_fifo;

    parameter DATA_WIDTH = 8;
    parameter ADDR_WIDTH = 3;
    parameter DEPTH      = 2**ADDR_WIDTH;
    parameter WR_CLK_PERIOD = 10;   // 100 MHz write clock
    parameter RD_CLK_PERIOD = 14;   // ~71 MHz read clock (different frequency)

    logic                    wr_clk, wr_rst_n, wr_en;
    logic [DATA_WIDTH-1:0]   wr_data;
    logic                    full;
    logic                    rd_clk, rd_rst_n, rd_en;
    logic [DATA_WIDTH-1:0]   rd_data;
    logic                    empty;

    async_fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) u_dut (.*);

    initial wr_clk = 1'b0;
    always #(WR_CLK_PERIOD/2) wr_clk = ~wr_clk;

    initial rd_clk = 1'b0;
    always #(RD_CLK_PERIOD/2) rd_clk = ~rd_clk;

    // Write side stimulus
    initial begin
        $display("=== ASYNC FIFO Testbench ===");

        wr_rst_n = 1'b0;
        wr_en    = 1'b0;
        wr_data  = '0;
        repeat (5) @(posedge wr_clk);
        wr_rst_n = 1'b1;
        repeat (3) @(posedge wr_clk);

        // Write data into FIFO
        $display("  Writing %0d entries...", DEPTH);
        for (int i = 0; i < DEPTH; i++) begin
            @(posedge wr_clk);
            wr_en   = 1'b1;
            wr_data = i[DATA_WIDTH-1:0];
        end
        @(posedge wr_clk);
        wr_en = 1'b0;

        // Wait for full flag (needs synchronizer delay)
        repeat (5) @(posedge wr_clk);
        $display("  After fill: full=%0b", full);

        // Wait for reads to drain, then write more
        repeat (30) @(posedge wr_clk);

        // Burst write
        for (int i = 0; i < 4; i++) begin
            @(posedge wr_clk);
            if (!full) begin
                wr_en   = 1'b1;
                wr_data = (8'hA0 + i)[DATA_WIDTH-1:0];
            end
        end
        @(posedge wr_clk);
        wr_en = 1'b0;

        repeat (50) @(posedge wr_clk);
    end

    // Read side stimulus
    int read_count;
    initial begin
        rd_rst_n = 1'b0;
        rd_en    = 1'b0;
        read_count = 0;
        repeat (5) @(posedge rd_clk);
        rd_rst_n = 1'b1;

        // Wait for data to be available
        repeat (10) @(posedge rd_clk);

        // Read everything
        $display("  Reading data...");
        repeat (30) begin
            @(posedge rd_clk);
            if (!empty) begin
                rd_en = 1'b1;
                @(posedge rd_clk);
                #1;
                $display("    Read[%0d]: data=0x%02h", read_count, rd_data);
                read_count++;
                rd_en = 1'b0;
            end
        end

        // Read remaining after second burst
        repeat (20) begin
            @(posedge rd_clk);
            if (!empty) begin
                rd_en = 1'b1;
                @(posedge rd_clk);
                #1;
                $display("    Read[%0d]: data=0x%02h", read_count, rd_data);
                read_count++;
                rd_en = 1'b0;
            end
        end

        $display("  Total reads: %0d", read_count);
        $display("=== ASYNC FIFO Testbench Complete ===");
        $finish;
    end

    initial begin
        #200000;
        $error("Simulation timeout!");
        $finish;
    end

endmodule
