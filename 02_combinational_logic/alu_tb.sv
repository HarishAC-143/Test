// Self-checking testbench for the ALU module.

module alu_tb;

    localparam int WIDTH = 8;

    logic [WIDTH-1:0] a, b, result;
    logic [2:0]       op;
    logic             zero, carry, overflow;

    alu #(.WIDTH(WIDTH)) dut (.*);

    int pass_count = 0;
    int fail_count = 0;

    initial begin
        $display("=== ALU Testbench (WIDTH=%0d) ===\n", WIDTH);

        // ADD tests
        check_alu(8'd10,  8'd20,  3'b000, 8'd30,  "ADD 10+20");
        check_alu(8'hFF,  8'h01,  3'b000, 8'h00,  "ADD overflow");
        check_alu(8'd0,   8'd0,   3'b000, 8'd0,   "ADD zero");

        // SUB tests
        check_alu(8'd50,  8'd20,  3'b001, 8'd30,  "SUB 50-20");
        check_alu(8'd0,   8'd1,   3'b001, 8'hFF,  "SUB underflow");

        // AND / OR / XOR
        check_alu(8'hAA,  8'h55,  3'b010, 8'h00,  "AND complementary");
        check_alu(8'hAA,  8'h55,  3'b011, 8'hFF,  "OR complementary");
        check_alu(8'hFF,  8'hFF,  3'b100, 8'h00,  "XOR same");

        // Shifts
        check_alu(8'h01,  8'd4,   3'b101, 8'h10,  "SLL by 4");
        check_alu(8'h80,  8'd4,   3'b110, 8'h08,  "SRL by 4");
        check_alu(8'h80,  8'd4,   3'b111, 8'hF8,  "SRA negative by 4");
        check_alu(8'h40,  8'd2,   3'b111, 8'h10,  "SRA positive by 2");

        $display("\nResults: %0d passed, %0d failed", pass_count, fail_count);
        if (fail_count == 0)
            $display("*** ALL TESTS PASSED ***");
        $finish;
    end

    task automatic check_alu(
        input logic [WIDTH-1:0] tv_a,
        input logic [WIDTH-1:0] tv_b,
        input logic [2:0]       tv_op,
        input logic [WIDTH-1:0] expected,
        input string            desc
    );
        a  = tv_a;
        b  = tv_b;
        op = tv_op;
        #1;

        if (result === expected) begin
            pass_count++;
            $display("PASS: %s => 0x%02h (zero=%0b carry=%0b ovf=%0b)",
                     desc, result, zero, carry, overflow);
        end else begin
            fail_count++;
            $display("FAIL: %s => got 0x%02h, expected 0x%02h",
                     desc, result, expected);
        end
    endtask

endmodule
