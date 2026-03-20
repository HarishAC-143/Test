// Testbench for Synchronous FIFO
// Demonstrates advanced testbench techniques: constrained random stimulus,
// reference model checking, coverage, and functional coverage groups.

`timescale 1ns / 1ps

module tb_sync_fifo;

    // =========================================================================
    // Parameters
    // =========================================================================
    localparam int DATA_WIDTH = 8;
    localparam int DEPTH      = 16;
    localparam int CLK_PERIOD = 10;
    localparam int NUM_TRANSACTIONS = 500;

    // =========================================================================
    // DUT Signals
    // =========================================================================
    logic                  clk;
    logic                  rst_n;
    logic                  wr_en;
    logic [DATA_WIDTH-1:0] wr_data;
    logic                  full;
    logic                  rd_en;
    logic [DATA_WIDTH-1:0] rd_data;
    logic                  empty;
    logic [$clog2(DEPTH):0] fill_level;

    // =========================================================================
    // Clock Generation
    // =========================================================================
    initial clk = 1'b0;
    always #(CLK_PERIOD/2) clk = ~clk;

    // =========================================================================
    // DUT Instantiation
    // =========================================================================
    sync_fifo #(
        .DATA_WIDTH (DATA_WIDTH),
        .DEPTH      (DEPTH)
    ) u_dut (
        .clk        (clk),
        .rst_n      (rst_n),
        .wr_en      (wr_en),
        .wr_data    (wr_data),
        .full       (full),
        .rd_en      (rd_en),
        .rd_data    (rd_data),
        .empty      (empty),
        .fill_level (fill_level)
    );

    // =========================================================================
    // Reference Model (golden model using SystemVerilog queue)
    // =========================================================================
    logic [DATA_WIDTH-1:0] ref_queue [$];

    // =========================================================================
    // Functional Coverage
    // =========================================================================
    covergroup cg_fifo @(posedge clk);
        cp_fill: coverpoint fill_level {
            bins empty_state   = {0};
            bins low_fill      = {[1:4]};
            bins mid_fill      = {[5:11]};
            bins high_fill     = {[12:15]};
            bins full_state    = {16};
        }

        cp_wr: coverpoint wr_en;
        cp_rd: coverpoint rd_en;

        cp_simultaneous: cross cp_wr, cp_rd {
            bins write_only = binsof(cp_wr) intersect {1} && binsof(cp_rd) intersect {0};
            bins read_only  = binsof(cp_wr) intersect {0} && binsof(cp_rd) intersect {1};
            bins both       = binsof(cp_wr) intersect {1} && binsof(cp_rd) intersect {1};
            bins neither    = binsof(cp_wr) intersect {0} && binsof(cp_rd) intersect {0};
        }
    endgroup

    cg_fifo fifo_cov = new();

    // =========================================================================
    // Scoreboard: check read data against reference model
    // =========================================================================
    int error_count = 0;
    int write_count = 0;
    int read_count  = 0;

    always @(posedge clk) begin
        if (rst_n) begin
            // Track writes
            if (wr_en && !full) begin
                ref_queue.push_back(wr_data);
                write_count++;
            end

            // Track reads and check data
            if (rd_en && !empty) begin
                automatic logic [DATA_WIDTH-1:0] expected = ref_queue.pop_front();
                read_count++;
                if (rd_data !== expected) begin
                    $error("MISMATCH at read #%0d: expected=0x%02h, got=0x%02h",
                           read_count, expected, rd_data);
                    error_count++;
                end
            end
        end
    end

    // =========================================================================
    // Stimulus Generation
    // =========================================================================
    task automatic reset_dut();
        rst_n   <= 1'b0;
        wr_en   <= 1'b0;
        rd_en   <= 1'b0;
        wr_data <= '0;
        repeat (5) @(posedge clk);
        rst_n   <= 1'b1;
        @(posedge clk);
    endtask

    initial begin
        int unsigned seed;
        $display("============================================");
        $display("  FIFO Testbench Starting");
        $display("  Transactions: %0d", NUM_TRANSACTIONS);
        $display("============================================");

        reset_dut();

        // Phase 1: Fill the FIFO completely
        $display("\n[Phase 1] Filling FIFO...");
        for (int i = 0; i < DEPTH; i++) begin
            @(posedge clk);
            wr_en   <= 1'b1;
            wr_data <= i[DATA_WIDTH-1:0];
        end
        @(posedge clk);
        wr_en <= 1'b0;
        assert (full) else $error("FIFO should be full after %0d writes", DEPTH);

        // Phase 2: Drain the FIFO completely
        $display("[Phase 2] Draining FIFO...");
        for (int i = 0; i < DEPTH; i++) begin
            @(posedge clk);
            rd_en <= 1'b1;
        end
        @(posedge clk);
        rd_en <= 1'b0;
        @(posedge clk);
        assert (empty) else $error("FIFO should be empty after draining");

        // Phase 3: Random read/write mix
        $display("[Phase 3] Random stimulus (%0d transactions)...", NUM_TRANSACTIONS);
        for (int t = 0; t < NUM_TRANSACTIONS; t++) begin
            @(posedge clk);
            wr_en   <= ($urandom_range(0, 1) == 1) && !full;
            rd_en   <= ($urandom_range(0, 1) == 1) && !empty;
            wr_data <= $urandom();
        end

        // Phase 4: Drain remaining
        @(posedge clk);
        wr_en <= 1'b0;
        while (!empty) begin
            @(posedge clk);
            rd_en <= 1'b1;
        end
        @(posedge clk);
        rd_en <= 1'b0;

        // Results
        repeat (5) @(posedge clk);
        $display("\n============================================");
        $display("  Writes:  %0d", write_count);
        $display("  Reads:   %0d", read_count);
        if (error_count == 0)
            $display("  RESULT:  ALL CHECKS PASSED");
        else
            $display("  RESULT:  %0d ERROR(S)", error_count);
        $display("============================================");

        $finish;
    end

    // Timeout
    initial begin
        #1000000;
        $error("TIMEOUT");
        $finish;
    end

    initial begin
        $dumpfile("tb_sync_fifo.vcd");
        $dumpvars(0, tb_sync_fifo);
    end

endmodule
