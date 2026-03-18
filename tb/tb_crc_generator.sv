// =============================================================================
// Testbench: CRC Generator
// =============================================================================

module tb_crc_generator;

    parameter int DATA_WIDTH = 8;
    parameter int CRC_WIDTH  = 32;

    logic                  clk;
    logic                  rst_n;
    logic                  clear;
    logic                  valid;
    logic [DATA_WIDTH-1:0] data_in;
    logic [CRC_WIDTH-1:0]  crc_out;
    logic                  crc_valid;

    crc_generator #(
        .DATA_WIDTH(DATA_WIDTH),
        .CRC_WIDTH(CRC_WIDTH)
    ) dut (.*);

    initial clk = 0;
    always #5 clk = ~clk;

    task automatic feed_byte(input logic [7:0] data);
        @(posedge clk);
        valid   = 1;
        data_in = data;
        @(posedge clk);
        valid = 0;
    endtask

    task automatic feed_string(input string s);
        for (int i = 0; i < s.len(); i++)
            feed_byte(s.getc(i));
    endtask

    initial begin
        $dumpfile("crc_waves.vcd");
        $dumpvars(0, tb_crc_generator);

        rst_n   = 0;
        clear   = 0;
        valid   = 0;
        data_in = 0;

        repeat(5) @(posedge clk);
        rst_n = 1;

        $display("\n=== Test 1: CRC of single byte 0x00 ===");
        feed_byte(8'h00);
        repeat(2) @(posedge clk);
        $display("  CRC = 0x%08h", crc_out);

        $display("\n=== Test 2: Clear and compute new CRC ===");
        @(posedge clk);
        clear = 1;
        @(posedge clk);
        clear = 0;

        feed_byte(8'hFF);
        repeat(2) @(posedge clk);
        $display("  CRC of 0xFF = 0x%08h", crc_out);

        $display("\n=== Test 3: Multi-byte CRC ===");
        @(posedge clk); clear = 1;
        @(posedge clk); clear = 0;

        feed_byte(8'h01);
        feed_byte(8'h02);
        feed_byte(8'h03);
        feed_byte(8'h04);
        repeat(2) @(posedge clk);
        $display("  CRC of {01,02,03,04} = 0x%08h", crc_out);

        $display("\n=== Test 4: CRC of ASCII string ===");
        @(posedge clk); clear = 1;
        @(posedge clk); clear = 0;

        feed_string("Hello");
        repeat(2) @(posedge clk);
        $display("  CRC of 'Hello' = 0x%08h", crc_out);

        $display("\n=== Test 5: Incremental CRC accumulation ===");
        @(posedge clk); clear = 1;
        @(posedge clk); clear = 0;

        for (int i = 0; i < 8; i++) begin
            feed_byte(8'(i));
            @(posedge clk);
            $display("  After byte %0d: CRC = 0x%08h", i, crc_out);
        end

        $display("\n=== All CRC tests completed ===");
        $finish;
    end

    initial begin
        #10000;
        $display("ERROR: Testbench timed out!");
        $finish;
    end

endmodule
