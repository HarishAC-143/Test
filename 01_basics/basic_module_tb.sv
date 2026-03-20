// Testbench for basic_adder — self-checking with assertions.

module basic_adder_tb;

    localparam int WIDTH = 8;
    localparam int NUM_TESTS = 100;

    logic [WIDTH-1:0] a, b, sum;
    logic             cin, cout;

    basic_adder #(.WIDTH(WIDTH)) dut (
        .a    (a),
        .b    (b),
        .cin  (cin),
        .sum  (sum),
        .cout (cout)
    );

    // Expected result computed in 2-state for comparison
    logic [WIDTH:0] expected;

    int pass_count = 0;
    int fail_count = 0;

    initial begin
        $display("=== basic_adder testbench (WIDTH=%0d) ===", WIDTH);

        // Exhaustive corner cases
        test_vector(8'h00, 8'h00, 1'b0);
        test_vector(8'hFF, 8'h00, 1'b0);
        test_vector(8'hFF, 8'h01, 1'b0);
        test_vector(8'hFF, 8'hFF, 1'b0);
        test_vector(8'hFF, 8'hFF, 1'b1);
        test_vector(8'h80, 8'h80, 1'b0);

        // Randomized tests
        for (int i = 0; i < NUM_TESTS; i++) begin
            test_vector($urandom, $urandom, $urandom & 1);
        end

        $display("\nResults: %0d passed, %0d failed", pass_count, fail_count);
        if (fail_count == 0)
            $display("*** ALL TESTS PASSED ***");
        else
            $display("*** SOME TESTS FAILED ***");

        $finish;
    end

    task automatic test_vector(
        input logic [WIDTH-1:0] tv_a,
        input logic [WIDTH-1:0] tv_b,
        input logic             tv_cin
    );
        a   = tv_a;
        b   = tv_b;
        cin = tv_cin;
        #1;

        expected = tv_a + tv_b + tv_cin;

        if ({cout, sum} === expected) begin
            pass_count++;
        end else begin
            fail_count++;
            $display("FAIL: a=0x%02h b=0x%02h cin=%0b => sum=0x%02h cout=%0b (expected 0x%03h)",
                     tv_a, tv_b, tv_cin, sum, cout, expected);
        end
    endtask

endmodule
