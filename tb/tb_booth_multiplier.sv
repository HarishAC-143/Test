// =============================================================================
// Testbench: Booth Multiplier
// =============================================================================

module tb_booth_multiplier;

    parameter int WIDTH = 16;

    logic               clk;
    logic               rst_n;
    logic               start;
    logic [WIDTH-1:0]   multiplicand;
    logic [WIDTH-1:0]   multiplier;
    logic [2*WIDTH-1:0] product;
    logic               done;
    logic               busy;

    booth_multiplier #(.WIDTH(WIDTH)) dut (.*);

    initial clk = 0;
    always #5 clk = ~clk;

    task automatic multiply(
        input logic signed [WIDTH-1:0] a,
        input logic signed [WIDTH-1:0] b
    );
        @(posedge clk);
        multiplicand = a;
        multiplier   = b;
        start        = 1;
        @(posedge clk);
        start = 0;

        wait(done);
        @(posedge clk);

        $display("  %0d x %0d = %0d (expected %0d) %s",
            $signed(a), $signed(b),
            $signed(product),
            $signed(a) * $signed(b),
            ($signed(product) == $signed(a) * $signed(b)) ? "PASS" : "FAIL");
    endtask

    initial begin
        $dumpfile("booth_waves.vcd");
        $dumpvars(0, tb_booth_multiplier);

        rst_n  = 0;
        start  = 0;
        multiplicand = 0;
        multiplier   = 0;

        repeat(5) @(posedge clk);
        rst_n = 1;
        repeat(2) @(posedge clk);

        $display("\n=== Booth Multiplier Tests ===");

        $display("\n--- Positive x Positive ---");
        multiply(16'd7, 16'd6);
        multiply(16'd100, 16'd200);
        multiply(16'd255, 16'd255);

        $display("\n--- Positive x Negative ---");
        multiply(16'd10, -16'd5);
        multiply(16'd127, -16'd1);

        $display("\n--- Negative x Negative ---");
        multiply(-16'd8, -16'd8);
        multiply(-16'd100, -16'd50);

        $display("\n--- Edge cases ---");
        multiply(16'd0, 16'd12345);
        multiply(16'd1, 16'd32767);
        multiply(-16'd1, 16'd1);

        $display("\n=== All Booth multiplier tests completed ===");
        $finish;
    end

    initial begin
        #100000;
        $display("ERROR: Testbench timed out!");
        $finish;
    end

endmodule
