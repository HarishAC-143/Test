// Testbench: Bus System (Master + Subordinate via Interface)
// Demonstrates end-to-end bus transactions through the simple_bus_if.

`timescale 1ns / 1ps

module tb_bus_system;

    parameter CLK_PERIOD = 10;

    logic clk, rst_n;

    // Instantiate interface
    simple_bus_if #(.ADDR_WIDTH(16), .DATA_WIDTH(32)) bus ();

    // Control signals for master
    logic        start_wr, start_rd;
    logic [15:0] target_addr;
    logic [31:0] wr_data, rd_data;
    logic        done;

    bus_master u_master (
        .clk         (clk),
        .rst_n       (rst_n),
        .start_wr    (start_wr),
        .start_rd    (start_rd),
        .target_addr (target_addr),
        .wr_data     (wr_data),
        .rd_data     (rd_data),
        .done        (done),
        .bus         (bus)
    );

    bus_subordinate #(.NUM_REGS(16)) u_sub (
        .clk   (clk),
        .rst_n (rst_n),
        .bus   (bus)
    );

    initial clk = 1'b0;
    always #(CLK_PERIOD/2) clk = ~clk;

    initial begin
        $display("=== BUS SYSTEM Testbench ===");

        rst_n       = 1'b0;
        start_wr    = 1'b0;
        start_rd    = 1'b0;
        target_addr = '0;
        wr_data     = '0;
        repeat (5) @(posedge clk);
        rst_n = 1'b1;
        repeat (3) @(posedge clk);

        // Write to register 0
        $display("  Writing 0xDEADBEEF to addr 0...");
        target_addr = 16'h0000;
        wr_data     = 32'hDEAD_BEEF;
        start_wr    = 1'b1;
        @(posedge clk);
        start_wr    = 1'b0;
        wait (done);
        @(posedge clk);
        $display("  Write complete  PASS");

        // Write to register 5
        $display("  Writing 0xCAFEBABE to addr 5...");
        target_addr = 16'h0005;
        wr_data     = 32'hCAFE_BABE;
        start_wr    = 1'b1;
        @(posedge clk);
        start_wr    = 1'b0;
        wait (done);
        @(posedge clk);
        $display("  Write complete  PASS");

        // Read back register 0
        $display("  Reading addr 0...");
        target_addr = 16'h0000;
        start_rd    = 1'b1;
        @(posedge clk);
        start_rd    = 1'b0;
        wait (done);
        @(posedge clk);
        #1;
        $display("  Read data: 0x%08h", rd_data);
        assert (rd_data == 32'hDEAD_BEEF)
            else $error("Readback addr 0: expected DEADBEEF, got %08h", rd_data);
        $display("  Readback addr 0  PASS");

        // Read back register 5
        $display("  Reading addr 5...");
        target_addr = 16'h0005;
        start_rd    = 1'b1;
        @(posedge clk);
        start_rd    = 1'b0;
        wait (done);
        @(posedge clk);
        #1;
        $display("  Read data: 0x%08h", rd_data);
        assert (rd_data == 32'hCAFE_BABE)
            else $error("Readback addr 5: expected CAFEBABE, got %08h", rd_data);
        $display("  Readback addr 5  PASS");

        $display("=== BUS SYSTEM All Tests Passed ===");
        $finish;
    end

    initial begin
        #100000;
        $error("Simulation timeout!");
        $finish;
    end

endmodule
