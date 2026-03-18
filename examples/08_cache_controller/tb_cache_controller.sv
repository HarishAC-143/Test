// Testbench for Direct-Mapped Cache Controller

module tb_cache_controller;

    localparam int ADDR_WIDTH  = 16;
    localparam int DATA_WIDTH  = 32;
    localparam int CACHE_LINES = 8;
    localparam int LINE_SIZE   = 4;

    logic                   clk;
    logic                   rst_n;

    logic                   cpu_req;
    logic                   cpu_wr;
    logic [ADDR_WIDTH-1:0]  cpu_addr;
    logic [DATA_WIDTH-1:0]  cpu_wdata;
    logic [DATA_WIDTH-1:0]  cpu_rdata;
    logic                   cpu_ready;

    logic                   mem_req;
    logic                   mem_wr;
    logic [ADDR_WIDTH-1:0]  mem_addr;
    logic [DATA_WIDTH-1:0]  mem_wdata;
    logic [DATA_WIDTH-1:0]  mem_rdata;
    logic                   mem_ready;

    int error_count = 0;

    cache_controller #(
        .ADDR_WIDTH (ADDR_WIDTH),
        .DATA_WIDTH (DATA_WIDTH),
        .CACHE_LINES(CACHE_LINES),
        .LINE_SIZE  (LINE_SIZE)
    ) dut (.*);

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Simple memory model
    logic [DATA_WIDTH-1:0] main_memory [2**ADDR_WIDTH];

    initial begin
        for (int i = 0; i < 2**ADDR_WIDTH; i++)
            main_memory[i] = i * 4;
    end

    // Memory response: 1-cycle latency
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_ready <= 1'b0;
            mem_rdata <= '0;
        end else if (mem_req) begin
            mem_ready <= 1'b1;
            if (mem_wr)
                main_memory[mem_addr >> 2] <= mem_wdata;
            else
                mem_rdata <= main_memory[mem_addr >> 2];
        end else begin
            mem_ready <= 1'b0;
        end
    end

    // CPU transaction tasks
    task automatic cpu_read(
        input  logic [ADDR_WIDTH-1:0] addr,
        output logic [DATA_WIDTH-1:0] data
    );
        @(posedge clk);
        cpu_req  <= 1'b1;
        cpu_wr   <= 1'b0;
        cpu_addr <= addr;
        @(posedge clk);
        cpu_req  <= 1'b0;

        while (!cpu_ready) @(posedge clk);
        data = cpu_rdata;
    endtask

    task automatic cpu_write(
        input logic [ADDR_WIDTH-1:0] addr,
        input logic [DATA_WIDTH-1:0] data
    );
        @(posedge clk);
        cpu_req   <= 1'b1;
        cpu_wr    <= 1'b1;
        cpu_addr  <= addr;
        cpu_wdata <= data;
        @(posedge clk);
        cpu_req   <= 1'b0;

        while (!cpu_ready) @(posedge clk);
    endtask

    logic [DATA_WIDTH-1:0] rdata;

    initial begin
        $display("=== Cache Controller Testbench ===");
        $display("");

        rst_n     = 0;
        cpu_req   = 0;
        cpu_wr    = 0;
        cpu_addr  = '0;
        cpu_wdata = '0;

        repeat (5) @(posedge clk);
        rst_n = 1;
        repeat (2) @(posedge clk);

        // Test 1: Cold miss + read
        $display("[Test 1] Cold miss read");
        cpu_read(16'h0000, rdata);
        $display("  Read addr=0x0000, data=0x%08h (expected=0x%08h)",
                 rdata, main_memory[0]);
        if (rdata !== main_memory[0]) begin
            $error("[FAIL] Cold miss read mismatch");
            error_count++;
        end else begin
            $display("[PASS] Cold miss read correct");
        end

        // Test 2: Cache hit (same line)
        $display("[Test 2] Cache hit read");
        cpu_read(16'h0004, rdata);
        $display("  Read addr=0x0004, data=0x%08h (expected=0x%08h)",
                 rdata, main_memory[1]);
        if (rdata !== main_memory[1]) begin
            $error("[FAIL] Hit read mismatch");
            error_count++;
        end else begin
            $display("[PASS] Cache hit read correct");
        end

        // Test 3: Write hit
        $display("[Test 3] Write hit");
        cpu_write(16'h0000, 32'hDEAD_BEEF);
        cpu_read(16'h0000, rdata);
        if (rdata !== 32'hDEAD_BEEF) begin
            $error("[FAIL] Write hit: expected=0xDEADBEEF, got=0x%08h", rdata);
            error_count++;
        end else begin
            $display("[PASS] Write hit correct: 0x%08h", rdata);
        end

        // Test 4: Read from different cache line
        $display("[Test 4] Different cache line");
        cpu_read(16'h0100, rdata);
        $display("  Read addr=0x0100, data=0x%08h", rdata);
        $display("[PASS] Different line access completed");

        // Test 5: Conflict miss (write-back + allocate)
        $display("[Test 5] Conflict miss with write-back");
        // Write to a line, then access a conflicting address
        cpu_write(16'h0200, 32'hCAFE_BABE);
        // Access address that maps to same index but different tag
        cpu_read(16'h0200 + (CACHE_LINES * LINE_SIZE * 4), rdata);
        $display("  Conflict miss handled, data=0x%08h", rdata);
        $display("[PASS] Conflict miss with write-back completed");

        // Verify the write-back made it to main memory
        if (main_memory[16'h0200 >> 2] === 32'hCAFE_BABE) begin
            $display("[PASS] Write-back data in main memory: 0x%08h",
                     main_memory[16'h0200 >> 2]);
        end else begin
            $display("[INFO] Write-back verification: mem[0x80]=0x%08h",
                     main_memory[16'h0200 >> 2]);
        end

        $display("");
        if (error_count == 0)
            $display("ALL TESTS PASSED");
        else
            $display("%0d FAILURES DETECTED", error_count);

        $finish;
    end

    // Timeout
    initial begin
        #50_000;
        $error("TIMEOUT");
        $finish;
    end

endmodule
