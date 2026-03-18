// =============================================================================
// Testbench: AXI4-Lite Slave Register Interface
// =============================================================================

module tb_axi_lite_slave;

    parameter int ADDR_WIDTH = 12;
    parameter int DATA_WIDTH = 32;
    parameter int NUM_REGS   = 16;

    logic clk, rst_n;

    logic [ADDR_WIDTH-1:0]   awaddr;
    logic                    awvalid, awready;
    logic [DATA_WIDTH-1:0]   wdata;
    logic [DATA_WIDTH/8-1:0] wstrb;
    logic                    wvalid, wready;
    logic [1:0]              bresp;
    logic                    bvalid, bready;
    logic [ADDR_WIDTH-1:0]   araddr;
    logic                    arvalid, arready;
    logic [DATA_WIDTH-1:0]   rdata;
    logic [1:0]              rresp;
    logic                    rvalid, rready;

    logic [NUM_REGS-1:0][DATA_WIDTH-1:0] reg_out;
    logic [NUM_REGS-1:0][DATA_WIDTH-1:0] reg_in;
    logic [NUM_REGS-1:0]                 reg_wr_en;

    axi_lite_slave #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .NUM_REGS(NUM_REGS)
    ) dut (
        .clk            (clk),
        .rst_n          (rst_n),
        .s_axi_awaddr   (awaddr),
        .s_axi_awvalid  (awvalid),
        .s_axi_awready  (awready),
        .s_axi_wdata    (wdata),
        .s_axi_wstrb    (wstrb),
        .s_axi_wvalid   (wvalid),
        .s_axi_wready   (wready),
        .s_axi_bresp    (bresp),
        .s_axi_bvalid   (bvalid),
        .s_axi_bready   (bready),
        .s_axi_araddr   (araddr),
        .s_axi_arvalid  (arvalid),
        .s_axi_arready  (arready),
        .s_axi_rdata    (rdata),
        .s_axi_rresp    (rresp),
        .s_axi_rvalid   (rvalid),
        .s_axi_rready   (rready),
        .reg_out        (reg_out),
        .reg_in         (reg_in),
        .reg_wr_en      (reg_wr_en)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    // AXI write transaction task
    task automatic axi_write(input logic [ADDR_WIDTH-1:0] addr, input logic [DATA_WIDTH-1:0] data);
        // Address phase
        @(posedge clk);
        awaddr  = addr;
        awvalid = 1;
        do @(posedge clk); while (!awready);
        awvalid = 0;

        // Data phase
        wdata  = data;
        wstrb  = '1;
        wvalid = 1;
        do @(posedge clk); while (!wready);
        wvalid = 0;

        // Response phase
        bready = 1;
        do @(posedge clk); while (!bvalid);
        $display("  Write: addr=0x%03h data=0x%08h resp=%0d", addr, data, bresp);
        bready = 0;
    endtask

    // AXI read transaction task
    task automatic axi_read(input logic [ADDR_WIDTH-1:0] addr, output logic [DATA_WIDTH-1:0] data);
        @(posedge clk);
        araddr  = addr;
        arvalid = 1;
        do @(posedge clk); while (!arready);
        arvalid = 0;

        rready = 1;
        do @(posedge clk); while (!rvalid);
        data = rdata;
        $display("  Read:  addr=0x%03h data=0x%08h resp=%0d", addr, rdata, rresp);
        rready = 0;
    endtask

    logic [DATA_WIDTH-1:0] read_data;

    initial begin
        $dumpfile("axi_lite_waves.vcd");
        $dumpvars(0, tb_axi_lite_slave);

        rst_n   = 0;
        awaddr  = 0; awvalid = 0;
        wdata   = 0; wstrb   = 0; wvalid = 0;
        bready  = 0;
        araddr  = 0; arvalid = 0;
        rready  = 0;
        reg_in  = '0;

        repeat(5) @(posedge clk);
        rst_n = 1;
        repeat(2) @(posedge clk);

        $display("\n=== Test 1: Write to registers ===");
        axi_write(12'h000, 32'hDEADBEEF);
        axi_write(12'h004, 32'hCAFECAFE);
        axi_write(12'h008, 32'h12345678);

        $display("\n=== Test 2: Read back registers ===");
        axi_read(12'h000, read_data);
        assert(read_data == 32'hDEADBEEF) else $error("Mismatch at 0x000!");
        axi_read(12'h004, read_data);
        assert(read_data == 32'hCAFECAFE) else $error("Mismatch at 0x004!");
        axi_read(12'h008, read_data);
        assert(read_data == 32'h12345678) else $error("Mismatch at 0x008!");

        $display("\n=== Test 3: Write with byte strobes ===");
        wstrb = 4'b0011;  // Only lower 2 bytes
        axi_write(12'h000, 32'hFFFFAAAA);
        axi_read(12'h000, read_data);
        $display("  Partial write result: 0x%08h (expected 0xDEADAAAA)", read_data);

        $display("\n=== Test 4: Register output check ===");
        $display("  reg_out[0] = 0x%08h", reg_out[0]);
        $display("  reg_out[1] = 0x%08h", reg_out[1]);
        $display("  reg_out[2] = 0x%08h", reg_out[2]);

        $display("\n=== All AXI-Lite tests completed ===");
        $finish;
    end

    initial begin
        #50000;
        $display("ERROR: Testbench timed out!");
        $finish;
    end

endmodule
