// Testbench: True Dual-Port RAM

`timescale 1ns / 1ps

module tb_dual_port_ram;

    parameter ADDR_WIDTH = 4;
    parameter DATA_WIDTH = 8;
    parameter CLK_A_PERIOD = 10;
    parameter CLK_B_PERIOD = 14;

    logic                    clk_a, clk_b;
    logic                    we_a, we_b;
    logic [ADDR_WIDTH-1:0]   addr_a, addr_b;
    logic [DATA_WIDTH-1:0]   wdata_a, wdata_b;
    logic [DATA_WIDTH-1:0]   rdata_a, rdata_b;

    dual_port_ram #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) u_dut (.*);

    initial clk_a = 1'b0;
    always #(CLK_A_PERIOD/2) clk_a = ~clk_a;

    initial clk_b = 1'b0;
    always #(CLK_B_PERIOD/2) clk_b = ~clk_b;

    initial begin
        $display("=== DUAL PORT RAM Testbench ===");

        we_a = 1'b0; we_b = 1'b0;
        addr_a = '0; addr_b = '0;
        wdata_a = '0; wdata_b = '0;

        // Port A writes
        $display("  Port A: writing...");
        for (int i = 0; i < 8; i++) begin
            @(posedge clk_a);
            we_a    = 1'b1;
            addr_a  = i[ADDR_WIDTH-1:0];
            wdata_a = (i * 11)[DATA_WIDTH-1:0];
        end
        @(posedge clk_a);
        we_a = 1'b0;

        // Port B reads what Port A wrote
        $display("  Port B: reading Port A's data...");
        for (int i = 0; i < 8; i++) begin
            @(posedge clk_b);
            addr_b = i[ADDR_WIDTH-1:0];
            @(posedge clk_b);
            #1;
            $display("    Addr %0d: read=0x%02h expected=0x%02h %s",
                     i, rdata_b, (i * 11)[DATA_WIDTH-1:0],
                     (rdata_b == (i * 11)[DATA_WIDTH-1:0]) ? "PASS" : "FAIL");
        end

        // Port B writes
        $display("  Port B: writing...");
        for (int i = 8; i < 16; i++) begin
            @(posedge clk_b);
            we_b    = 1'b1;
            addr_b  = i[ADDR_WIDTH-1:0];
            wdata_b = (i * 7)[DATA_WIDTH-1:0];
        end
        @(posedge clk_b);
        we_b = 1'b0;

        // Port A reads what Port B wrote
        $display("  Port A: reading Port B's data...");
        for (int i = 8; i < 16; i++) begin
            @(posedge clk_a);
            addr_a = i[ADDR_WIDTH-1:0];
            @(posedge clk_a);
            #1;
            $display("    Addr %0d: read=0x%02h expected=0x%02h %s",
                     i, rdata_a, (i * 7)[DATA_WIDTH-1:0],
                     (rdata_a == (i * 7)[DATA_WIDTH-1:0]) ? "PASS" : "FAIL");
        end

        $display("=== DUAL PORT RAM Testbench Complete ===");
        $finish;
    end

    initial begin
        #100000;
        $error("Simulation timeout!");
        $finish;
    end

endmodule
