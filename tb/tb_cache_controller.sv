// =============================================================================
// Testbench: Cache Controller
// =============================================================================

module tb_cache_controller;

    parameter int ADDR_WIDTH  = 32;
    parameter int DATA_WIDTH  = 32;
    parameter int CACHE_SIZE  = 256;
    parameter int BLOCK_SIZE  = 16;

    logic                  clk;
    logic                  rst_n;

    logic [ADDR_WIDTH-1:0] cpu_addr;
    logic [DATA_WIDTH-1:0] cpu_wr_data;
    logic                  cpu_rd_en;
    logic                  cpu_wr_en;
    logic [DATA_WIDTH-1:0] cpu_rd_data;
    logic                  cpu_ready;

    logic [ADDR_WIDTH-1:0] mem_addr;
    logic [DATA_WIDTH-1:0] mem_wr_data;
    logic                  mem_rd_en;
    logic                  mem_wr_en;
    logic [DATA_WIDTH-1:0] mem_rd_data;
    logic                  mem_ready;

    cache_controller #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .CACHE_SIZE(CACHE_SIZE),
        .BLOCK_SIZE(BLOCK_SIZE)
    ) dut (.*);

    initial clk = 0;
    always #5 clk = ~clk;

    // Simple memory model
    logic [DATA_WIDTH-1:0] main_memory [256];

    always_ff @(posedge clk) begin
        mem_ready <= 1'b0;
        if (mem_rd_en) begin
            mem_rd_data <= main_memory[mem_addr[9:2]];
            mem_ready   <= 1'b1;
        end else if (mem_wr_en) begin
            main_memory[mem_addr[9:2]] <= mem_wr_data;
            mem_ready <= 1'b1;
        end
    end

    task automatic cpu_write(input logic [31:0] addr, input logic [31:0] data);
        wait(cpu_ready);
        @(posedge clk);
        cpu_addr    = addr;
        cpu_wr_data = data;
        cpu_wr_en   = 1;
        @(posedge clk);
        cpu_wr_en = 0;
        wait(cpu_ready);
        $display("  WRITE: addr=0x%08h data=0x%08h", addr, data);
    endtask

    task automatic cpu_read(input logic [31:0] addr, output logic [31:0] data);
        wait(cpu_ready);
        @(posedge clk);
        cpu_addr  = addr;
        cpu_rd_en = 1;
        @(posedge clk);
        cpu_rd_en = 0;
        wait(cpu_ready);
        data = cpu_rd_data;
        $display("  READ:  addr=0x%08h data=0x%08h", addr, cpu_rd_data);
    endtask

    logic [31:0] read_data;

    initial begin
        $dumpfile("cache_waves.vcd");
        $dumpvars(0, tb_cache_controller);

        rst_n       = 0;
        cpu_addr    = 0;
        cpu_wr_data = 0;
        cpu_rd_en   = 0;
        cpu_wr_en   = 0;
        mem_rd_data = 0;
        mem_ready   = 0;

        // Initialize memory
        for (int i = 0; i < 256; i++)
            main_memory[i] = 32'hBASE_0000 + i;

        repeat(5) @(posedge clk);
        rst_n = 1;
        repeat(2) @(posedge clk);

        $display("\n=== Test 1: Cold miss reads (compulsory misses) ===");
        cpu_read(32'h0000_0000, read_data);
        cpu_read(32'h0000_0004, read_data);

        $display("\n=== Test 2: Cache hits (same block) ===");
        cpu_read(32'h0000_0000, read_data);
        cpu_read(32'h0000_0004, read_data);

        $display("\n=== Test 3: Write and read back ===");
        cpu_write(32'h0000_0000, 32'hDEADBEEF);
        cpu_read(32'h0000_0000, read_data);
        assert(read_data == 32'hDEADBEEF)
            else $error("Write-read mismatch!");

        $display("\n=== Test 4: Conflict miss (different address, same index) ===");
        cpu_write(32'h0000_0100, 32'hCAFECAFE);
        cpu_read(32'h0000_0100, read_data);

        $display("\n=== Test 5: Read back original (dirty writeback) ===");
        cpu_read(32'h0000_0000, read_data);

        repeat(10) @(posedge clk);
        $display("\n=== All cache controller tests completed ===");
        $finish;
    end

    initial begin
        #200000;
        $display("ERROR: Testbench timed out!");
        $finish;
    end

endmodule
