// =============================================================================
// Testbench: Multi-Stage Pipelined ALU
// =============================================================================

module tb_pipelined_alu;
    import alu_pkg::*;

    logic        clk;
    logic        rst_n;
    logic        flush;
    logic        stall;
    logic        valid_in;
    alu_op_e     op_in;
    logic [31:0] operand_a;
    logic [31:0] operand_b;
    logic [4:0]  rd_addr_in;
    logic        fwd_valid;
    logic [4:0]  fwd_addr;
    logic [31:0] fwd_data;
    logic        valid_out;
    logic [31:0] result;
    logic [4:0]  rd_addr_out;
    logic        overflow;

    pipelined_alu dut (.*);

    initial clk = 0;
    always #5 clk = ~clk;

    task automatic issue_op(
        input alu_op_e op,
        input logic [31:0] a,
        input logic [31:0] b,
        input logic [4:0] rd
    );
        @(posedge clk);
        valid_in   = 1;
        op_in      = op;
        operand_a  = a;
        operand_b  = b;
        rd_addr_in = rd;
        @(posedge clk);
        valid_in = 0;
    endtask

    initial begin
        $dumpfile("alu_waves.vcd");
        $dumpvars(0, tb_pipelined_alu);

        rst_n      = 0;
        flush      = 0;
        stall      = 0;
        valid_in   = 0;
        op_in      = ALU_ADD;
        operand_a  = 0;
        operand_b  = 0;
        rd_addr_in = 0;
        fwd_valid  = 0;
        fwd_addr   = 0;
        fwd_data   = 0;

        repeat(5) @(posedge clk);
        rst_n = 1;

        $display("\n=== Test 1: ADD 100 + 200 ===");
        issue_op(ALU_ADD, 32'd100, 32'd200, 5'd1);
        repeat(3) @(posedge clk);
        $display("Result: %0d (expected 300), valid=%0b", result, valid_out);

        $display("\n=== Test 2: SUB 500 - 123 ===");
        issue_op(ALU_SUB, 32'd500, 32'd123, 5'd2);
        repeat(3) @(posedge clk);
        $display("Result: %0d (expected 377), valid=%0b", result, valid_out);

        $display("\n=== Test 3: AND ===");
        issue_op(ALU_AND, 32'hFF00FF00, 32'h0F0F0F0F, 5'd3);
        repeat(3) @(posedge clk);
        $display("Result: 0x%08h (expected 0x0F000F00)", result);

        $display("\n=== Test 4: Shift left ===");
        issue_op(ALU_SLL, 32'd1, 32'd8, 5'd4);
        repeat(3) @(posedge clk);
        $display("Result: %0d (expected 256)", result);

        $display("\n=== Test 5: MUL 7 * 6 ===");
        issue_op(ALU_MUL, 32'd7, 32'd6, 5'd5);
        repeat(3) @(posedge clk);
        $display("Result: %0d (expected 42)", result);

        $display("\n=== Test 6: Pipeline flush ===");
        issue_op(ALU_ADD, 32'd999, 32'd1, 5'd6);
        @(posedge clk);
        flush = 1;
        @(posedge clk);
        flush = 0;
        repeat(3) @(posedge clk);
        $display("Valid after flush: %0b (expected 0)", valid_out);

        $display("\n=== Test 7: Pipeline stall ===");
        issue_op(ALU_ADD, 32'd50, 32'd50, 5'd7);
        @(posedge clk);
        stall = 1;
        repeat(3) @(posedge clk);
        stall = 0;
        repeat(3) @(posedge clk);
        $display("Result after stall: %0d (expected 100)", result);

        $display("\n=== All ALU tests completed ===");
        $finish;
    end

    initial begin
        #10000;
        $display("ERROR: Testbench timed out!");
        $finish;
    end

endmodule
