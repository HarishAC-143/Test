// Testbench for ALU module
// Demonstrates SystemVerilog testbench techniques: tasks, assertions, coverage

module alu_tb;

    parameter WIDTH = 32;

    logic [WIDTH-1:0] operand_a, operand_b;
    logic [3:0]       alu_op;
    logic [WIDTH-1:0] result;
    logic             zero, carry, overflow;

    // Instantiate the DUT
    alu #(.WIDTH(WIDTH)) dut (
        .operand_a (operand_a),
        .operand_b (operand_b),
        .alu_op    (alu_op),
        .result    (result),
        .zero      (zero),
        .carry     (carry),
        .overflow  (overflow)
    );

    // Clock generation (for timing assertions)
    logic clk = 0;
    always #5 clk = ~clk;

    // Test task: verify ALU operation
    task automatic test_alu(
        input  logic [WIDTH-1:0] a,
        input  logic [WIDTH-1:0] b,
        input  logic [3:0]       op,
        input  logic [WIDTH-1:0] expected,
        input  string            op_name
    );
        operand_a = a;
        operand_b = b;
        alu_op    = op;
        #1;
        if (result !== expected) begin
            $error("FAIL: %s: %0h op %0h = %0h, expected %0h",
                   op_name, a, b, result, expected);
        end else begin
            $display("PASS: %s: %0h op %0h = %0h", op_name, a, b, result);
        end
    endtask

    // Main test sequence
    initial begin
        $display("=== ALU Testbench ===");
        $display("");

        // Test ADD
        test_alu(32'd10, 32'd20, 4'b0000, 32'd30, "ADD");
        test_alu(32'hFFFFFFFF, 32'd1, 4'b0000, 32'd0, "ADD overflow");

        // Test SUB
        test_alu(32'd50, 32'd20, 4'b0001, 32'd30, "SUB");
        test_alu(32'd0, 32'd1, 4'b0001, 32'hFFFFFFFF, "SUB underflow");

        // Test AND
        test_alu(32'hFF00FF00, 32'h0F0F0F0F, 4'b0010, 32'h0F000F00, "AND");

        // Test OR
        test_alu(32'hFF00FF00, 32'h0F0F0F0F, 4'b0011, 32'hFF0FFF0F, "OR");

        // Test XOR
        test_alu(32'hAAAAAAAA, 32'h55555555, 4'b0100, 32'hFFFFFFFF, "XOR");

        // Test SLL (shift left logical)
        test_alu(32'd1, 32'd4, 4'b0101, 32'd16, "SLL");

        // Test SRL (shift right logical)
        test_alu(32'd256, 32'd4, 4'b0110, 32'd16, "SRL");

        // Test zero flag
        operand_a = 32'd5;
        operand_b = 32'd5;
        alu_op    = 4'b0001;
        #1;
        assert (zero == 1'b1) else $error("Zero flag should be set for 5-5");
        $display("PASS: Zero flag for SUB 5-5 = %b", zero);

        // Test SLT (set less than)
        test_alu(-32'sd5, 32'sd3, 4'b1000, 32'd1, "SLT -5<3");
        test_alu(32'sd3, -32'sd5, 4'b1000, 32'd0, "SLT 3<-5");

        $display("");
        $display("=== All tests completed ===");
        $finish;
    end

    // Dump waveforms
    initial begin
        $dumpfile("alu_tb.vcd");
        $dumpvars(0, alu_tb);
    end

endmodule
