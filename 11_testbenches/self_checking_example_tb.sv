// Self-checking testbench example.
// Verifies a simple module (edge_detector from section 03) using a reference model.

module self_checking_example_tb;

    localparam int CLK_PERIOD = 10;

    logic clk, rst_n;
    logic signal_in;
    logic rising_edge, falling_edge, any_edge;

    // DUT
    edge_detector dut (
        .clk          (clk),
        .rst_n        (rst_n),
        .signal_in    (signal_in),
        .rising_edge  (rising_edge),
        .falling_edge (falling_edge),
        .any_edge     (any_edge)
    );

    // Clock
    initial clk = 1'b0;
    always #(CLK_PERIOD/2) clk = ~clk;

    // Reference model
    logic ref_prev;
    logic ref_rising, ref_falling, ref_any;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            ref_prev <= 1'b0;
        else
            ref_prev <= signal_in;
    end

    assign ref_rising  =  signal_in & ~ref_prev;
    assign ref_falling = ~signal_in &  ref_prev;
    assign ref_any     =  signal_in ^  ref_prev;

    // Checker
    int error_count = 0;
    int check_count = 0;

    task automatic verify(input string label);
        check_count++;
        if (rising_edge !== ref_rising ||
            falling_edge !== ref_falling ||
            any_edge !== ref_any) begin
            error_count++;
            $display("FAIL [%0t] %s: DUT(r=%b f=%b a=%b) REF(r=%b f=%b a=%b)",
                     $time, label,
                     rising_edge, falling_edge, any_edge,
                     ref_rising, ref_falling, ref_any);
        end
    endtask

    // Stimulus
    initial begin
        $display("=== Edge Detector Self-Checking Testbench ===\n");

        rst_n     = 1'b0;
        signal_in = 1'b0;
        repeat (5) @(posedge clk);
        rst_n = 1'b1;

        // Deterministic patterns
        repeat (3) @(posedge clk);
        verify("idle low");

        signal_in = 1'b1;
        @(posedge clk); #1;
        verify("rising edge");

        @(posedge clk); #1;
        verify("held high");

        signal_in = 1'b0;
        @(posedge clk); #1;
        verify("falling edge");

        @(posedge clk); #1;
        verify("held low");

        // Toggling pattern
        for (int i = 0; i < 20; i++) begin
            signal_in = ~signal_in;
            @(posedge clk); #1;
            verify($sformatf("toggle %0d", i));
        end

        // Random stimulus
        for (int i = 0; i < 100; i++) begin
            signal_in = $urandom & 1;
            @(posedge clk); #1;
            verify($sformatf("random %0d", i));
        end

        $display("\nChecks: %0d, Errors: %0d", check_count, error_count);
        if (error_count == 0)
            $display("*** ALL TESTS PASSED ***");
        else
            $display("*** %0d TESTS FAILED ***", error_count);

        $finish;
    end

    initial begin
        $dumpfile("edge_detector.vcd");
        $dumpvars(0, self_checking_example_tb);
    end

endmodule
