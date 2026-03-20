// Testbench: Single-Port RAM

`timescale 1ns / 1ps

module tb_single_port_ram;

    parameter ADDR_WIDTH = 4;
    parameter DATA_WIDTH = 8;
    parameter DEPTH      = 2**ADDR_WIDTH;
    parameter CLK_PERIOD = 10;

    logic                    clk;
    logic                    we;
    logic [ADDR_WIDTH-1:0]   addr;
    logic [DATA_WIDTH-1:0]   wdata, rdata;

    single_port_ram #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) u_dut (.*);

    initial clk = 1'b0;
    always #(CLK_PERIOD/2) clk = ~clk;

    initial begin
        $display("=== SINGLE PORT RAM Testbench ===");

        we    = 1'b0;
        addr  = '0;
        wdata = '0;

        // Write sequential data
        $display("  Writing data...");
        for (int i = 0; i < DEPTH; i++) begin
            we    = 1'b1;
            addr  = i[ADDR_WIDTH-1:0];
            wdata = (i * 17)[DATA_WIDTH-1:0];  // arbitrary pattern
            @(posedge clk);
        end
        we = 1'b0;
        @(posedge clk);

        // Read back and verify
        $display("  Reading and verifying...");
        for (int i = 0; i < DEPTH; i++) begin
            addr = i[ADDR_WIDTH-1:0];
            @(posedge clk);  // one cycle latency for registered read
            @(posedge clk);
            #1;
            assert (rdata == (i * 17)[DATA_WIDTH-1:0])
                else $error("Addr %0d: expected %02h, got %02h",
                            i, (i * 17)[DATA_WIDTH-1:0], rdata);
        end
        $display("  All locations verified  PASS");

        // Overwrite and re-read
        we    = 1'b1;
        addr  = 4'd5;
        wdata = 8'hFF;
        @(posedge clk);
        we = 1'b0;
        @(posedge clk);
        @(posedge clk);
        #1;
        assert (rdata == 8'hFF)
            else $error("Overwrite: expected FF, got %02h", rdata);
        $display("  Overwrite addr 5: rdata=%02h  PASS", rdata);

        $display("=== SINGLE PORT RAM All Tests Passed ===");
        $finish;
    end

    initial begin
        #100000;
        $error("Simulation timeout!");
        $finish;
    end

endmodule
