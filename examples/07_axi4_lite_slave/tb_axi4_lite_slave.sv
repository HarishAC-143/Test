// Testbench for AXI4-Lite Slave Interface

module tb_axi4_lite_slave;

    localparam int ADDR_WIDTH = 4;
    localparam int DATA_WIDTH = 32;

    logic                    aclk;
    logic                    aresetn;

    logic [ADDR_WIDTH-1:0]   s_axi_awaddr;
    logic                    s_axi_awvalid;
    logic                    s_axi_awready;

    logic [DATA_WIDTH-1:0]   s_axi_wdata;
    logic [DATA_WIDTH/8-1:0] s_axi_wstrb;
    logic                    s_axi_wvalid;
    logic                    s_axi_wready;

    logic [1:0]              s_axi_bresp;
    logic                    s_axi_bvalid;
    logic                    s_axi_bready;

    logic [ADDR_WIDTH-1:0]   s_axi_araddr;
    logic                    s_axi_arvalid;
    logic                    s_axi_arready;

    logic [DATA_WIDTH-1:0]   s_axi_rdata;
    logic [1:0]              s_axi_rresp;
    logic                    s_axi_rvalid;
    logic                    s_axi_rready;

    logic [DATA_WIDTH-1:0]   reg_ctrl;
    logic [DATA_WIDTH-1:0]   reg_status;
    logic [DATA_WIDTH-1:0]   reg_data0;
    logic [DATA_WIDTH-1:0]   reg_data1;

    int error_count = 0;

    axi4_lite_slave #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) dut (.*);

    initial begin
        aclk = 0;
        forever #5 aclk = ~aclk;
    end

    // AXI4-Lite write transaction task
    task automatic axi_write(
        input logic [ADDR_WIDTH-1:0]   addr,
        input logic [DATA_WIDTH-1:0]   data,
        input logic [DATA_WIDTH/8-1:0] strb = '1
    );
        // Drive address and data simultaneously
        @(posedge aclk);
        s_axi_awaddr  <= addr;
        s_axi_awvalid <= 1'b1;
        s_axi_wdata   <= data;
        s_axi_wstrb   <= strb;
        s_axi_wvalid  <= 1'b1;
        s_axi_bready  <= 1'b1;

        // Wait for address handshake
        fork
            begin
                do @(posedge aclk); while (!s_axi_awready);
                s_axi_awvalid <= 1'b0;
            end
            begin
                do @(posedge aclk); while (!s_axi_wready);
                s_axi_wvalid <= 1'b0;
            end
        join

        // Wait for write response
        do @(posedge aclk); while (!s_axi_bvalid);
        s_axi_bready <= 1'b0;
        @(posedge aclk);
    endtask

    // AXI4-Lite read transaction task
    task automatic axi_read(
        input  logic [ADDR_WIDTH-1:0]  addr,
        output logic [DATA_WIDTH-1:0]  data
    );
        @(posedge aclk);
        s_axi_araddr  <= addr;
        s_axi_arvalid <= 1'b1;
        s_axi_rready  <= 1'b1;

        // Wait for address handshake
        do @(posedge aclk); while (!s_axi_arready);
        s_axi_arvalid <= 1'b0;

        // Wait for read data
        do @(posedge aclk); while (!s_axi_rvalid);
        data = s_axi_rdata;
        s_axi_rready <= 1'b0;
        @(posedge aclk);
    endtask

    logic [DATA_WIDTH-1:0] read_data;

    initial begin
        $display("=== AXI4-Lite Slave Testbench ===");
        $display("");

        aresetn       = 0;
        s_axi_awaddr  = '0;
        s_axi_awvalid = 0;
        s_axi_wdata   = '0;
        s_axi_wstrb   = '0;
        s_axi_wvalid  = 0;
        s_axi_bready  = 0;
        s_axi_araddr  = '0;
        s_axi_arvalid = 0;
        s_axi_rready  = 0;
        reg_status    = 32'hDEAD_BEEF;

        repeat (5) @(posedge aclk);
        aresetn = 1;
        repeat (2) @(posedge aclk);

        // Test 1: Write to CTRL register (0x00)
        $display("[Test 1] Write CTRL register");
        axi_write(4'h0, 32'hA5A5_A5A5);
        if (reg_ctrl !== 32'hA5A5_A5A5) begin
            $error("[FAIL] CTRL: expected=0xA5A5A5A5, got=0x%08h", reg_ctrl);
            error_count++;
        end else begin
            $display("[PASS] CTRL = 0x%08h", reg_ctrl);
        end

        // Test 2: Read back CTRL register
        $display("[Test 2] Read CTRL register");
        axi_read(4'h0, read_data);
        if (read_data !== 32'hA5A5_A5A5) begin
            $error("[FAIL] Read CTRL: expected=0xA5A5A5A5, got=0x%08h", read_data);
            error_count++;
        end else begin
            $display("[PASS] Read CTRL = 0x%08h", read_data);
        end

        // Test 3: Read STATUS register (read-only, driven by reg_status input)
        $display("[Test 3] Read STATUS register");
        axi_read(4'h4, read_data);
        if (read_data !== 32'hDEAD_BEEF) begin
            $error("[FAIL] Read STATUS: expected=0xDEADBEEF, got=0x%08h", read_data);
            error_count++;
        end else begin
            $display("[PASS] Read STATUS = 0x%08h", read_data);
        end

        // Test 4: Write to STATUS should be ignored
        $display("[Test 4] Write STATUS (should be ignored)");
        axi_write(4'h4, 32'h1234_5678);
        reg_status = 32'hDEAD_BEEF;
        axi_read(4'h4, read_data);
        if (read_data !== 32'hDEAD_BEEF) begin
            $error("[FAIL] STATUS should remain 0xDEADBEEF, got=0x%08h", read_data);
            error_count++;
        end else begin
            $display("[PASS] STATUS unchanged after write attempt");
        end

        // Test 5: Write and read DATA0
        $display("[Test 5] Write/Read DATA0");
        axi_write(4'h8, 32'hCAFE_BABE);
        axi_read(4'h8, read_data);
        if (read_data !== 32'hCAFE_BABE) begin
            $error("[FAIL] DATA0: expected=0xCAFEBABE, got=0x%08h", read_data);
            error_count++;
        end else begin
            $display("[PASS] DATA0 = 0x%08h", read_data);
        end

        // Test 6: Write and read DATA1
        $display("[Test 6] Write/Read DATA1");
        axi_write(4'hC, 32'h0000_FFFF);
        axi_read(4'hC, read_data);
        if (read_data !== 32'h0000_FFFF) begin
            $error("[FAIL] DATA1: expected=0x0000FFFF, got=0x%08h", read_data);
            error_count++;
        end else begin
            $display("[PASS] DATA1 = 0x%08h", read_data);
        end

        // Test 7: Byte-strobe write
        $display("[Test 7] Byte-strobe partial write");
        axi_write(4'h8, 32'h0000_0000);  // Clear DATA0
        axi_write(4'h8, 32'hFF00_00FF, 4'b1001);  // Write only bytes 0 and 3
        axi_read(4'h8, read_data);
        if (read_data !== 32'hFF00_00FF) begin
            $error("[FAIL] Byte strobe: expected=0xFF0000FF, got=0x%08h", read_data);
            error_count++;
        end else begin
            $display("[PASS] Byte-strobe write correct: 0x%08h", read_data);
        end

        $display("");
        if (error_count == 0)
            $display("ALL TESTS PASSED");
        else
            $display("%0d FAILURES DETECTED", error_count);

        $finish;
    end

endmodule
