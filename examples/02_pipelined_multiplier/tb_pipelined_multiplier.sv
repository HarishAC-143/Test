// Testbench for 4-Stage Pipelined Multiplier

module tb_pipelined_multiplier;

    localparam int WIDTH = 16;
    localparam int PIPELINE_DEPTH = 4;

    logic                  clk;
    logic                  rst_n;
    logic                  valid_in;
    logic [WIDTH-1:0]      operand_a;
    logic [WIDTH-1:0]      operand_b;
    logic                  valid_out;
    logic [2*WIDTH-1:0]    product;

    int error_count = 0;
    int test_count  = 0;

    // Expected results queue to account for pipeline latency
    logic [2*WIDTH-1:0] expected_queue[$];

    pipelined_multiplier #(.WIDTH(WIDTH)) dut (.*);

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    task automatic send_operands(
        input logic [WIDTH-1:0] a,
        input logic [WIDTH-1:0] b
    );
        @(posedge clk);
        valid_in  <= 1'b1;
        operand_a <= a;
        operand_b <= b;
        expected_queue.push_back(a * b);
    endtask

    task automatic send_idle();
        @(posedge clk);
        valid_in  <= 1'b0;
        operand_a <= '0;
        operand_b <= '0;
    endtask

    // Monitor output
    always @(posedge clk) begin
        if (valid_out) begin
            automatic logic [2*WIDTH-1:0] expected;
            test_count++;
            if (expected_queue.size() > 0) begin
                expected = expected_queue.pop_front();
                if (product !== expected) begin
                    $error("[FAIL] Test %0d: expected=0x%08h, got=0x%08h",
                           test_count, expected, product);
                    error_count++;
                end else begin
                    $display("[PASS] Test %0d: %0d = 0x%08h",
                             test_count, product, product);
                end
            end
        end
    end

    initial begin
        rst_n    = 0;
        valid_in = 0;
        operand_a = '0;
        operand_b = '0;

        repeat (3) @(posedge clk);
        rst_n = 1;
        @(posedge clk);

        $display("=== Pipelined Multiplier Testbench ===");
        $display("");

        // Test 1: Simple multiplication
        send_operands(16'd10, 16'd20);

        // Test 2: Powers of 2
        send_operands(16'd256, 16'd128);

        // Test 3: Maximum values
        send_operands(16'hFFFF, 16'hFFFF);

        // Test 4: Multiply by zero
        send_operands(16'd12345, 16'd0);

        // Test 5: Multiply by one
        send_operands(16'd42, 16'd1);

        // Test 6-10: Consecutive operations to test pipeline throughput
        send_operands(16'd100, 16'd200);
        send_operands(16'd300, 16'd400);
        send_operands(16'd500, 16'd600);
        send_operands(16'd7, 16'd11);
        send_operands(16'd1000, 16'd1000);

        // Stop sending, wait for pipeline to drain
        send_idle();

        repeat (PIPELINE_DEPTH + 2) @(posedge clk);

        $display("");
        $display("=== Results: %0d/%0d tests passed ===",
                 test_count - error_count, test_count);
        if (error_count == 0)
            $display("ALL TESTS PASSED");
        else
            $display("FAILURES DETECTED");

        $finish;
    end

endmodule
