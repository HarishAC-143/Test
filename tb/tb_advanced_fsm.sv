// =============================================================================
// Testbench: Advanced FSM (AXI-Stream Packet Processor)
// =============================================================================

module tb_advanced_fsm;

    parameter int DATA_WIDTH = 32;

    logic                  clk;
    logic                  rst_n;
    logic [DATA_WIDTH-1:0] s_axis_tdata;
    logic                  s_axis_tvalid;
    logic                  s_axis_tlast;
    logic                  s_axis_tready;
    logic [DATA_WIDTH-1:0] m_axis_tdata;
    logic                  m_axis_tvalid;
    logic                  m_axis_tlast;
    logic                  m_axis_tready;
    logic                  pkt_error;
    logic [31:0]           pkt_count;
    logic [31:0]           error_count;

    advanced_fsm #(.DATA_WIDTH(DATA_WIDTH)) dut (.*);

    initial clk = 0;
    always #5 clk = ~clk;

    task automatic send_word(input logic [31:0] data, input logic last);
        s_axis_tdata  = data;
        s_axis_tvalid = 1;
        s_axis_tlast  = last;
        do @(posedge clk); while (!s_axis_tready);
        s_axis_tvalid = 0;
        s_axis_tlast  = 0;
    endtask

    initial begin
        $dumpfile("fsm_waves.vcd");
        $dumpvars(0, tb_advanced_fsm);

        rst_n         = 0;
        s_axis_tdata  = 0;
        s_axis_tvalid = 0;
        s_axis_tlast  = 0;
        m_axis_tready = 1;

        repeat(5) @(posedge clk);
        rst_n = 1;
        repeat(2) @(posedge clk);

        $display("\n=== Test 1: Valid packet (header + 1 word payload + trailer) ===");
        // Header: length=4 (1 word), src=1, dst=2, type=DATA
        send_word({16'd4, 8'd1, 8'd2}, 0);
        // Payload
        send_word(32'hDEADBEEF, 0);
        // Trailer
        send_word(32'hCAFECAFE, 1);

        repeat(3) @(posedge clk);
        $display("Packet count: %0d, Error count: %0d", pkt_count, error_count);

        $display("\n=== Test 2: Error packet (zero length) ===");
        send_word({16'd0, 8'd1, 8'd2}, 1);
        repeat(3) @(posedge clk);
        $display("Error count after bad pkt: %0d", error_count);

        $display("\n=== Test 3: Second valid packet ===");
        send_word({16'd8, 8'd3, 8'd4}, 0);
        send_word(32'h12345678, 0);
        send_word(32'h9ABCDEF0, 0);
        send_word(32'hAAAABBBB, 1);

        repeat(5) @(posedge clk);
        $display("Final packet count: %0d, error count: %0d", pkt_count, error_count);

        $display("\n=== All FSM tests completed ===");
        $finish;
    end

    initial begin
        #20000;
        $display("ERROR: Testbench timed out!");
        $finish;
    end

endmodule
