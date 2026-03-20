// Testbench: 4-to-1 Multiplexer

`timescale 1ns / 1ps

module tb_mux4to1;

    parameter WIDTH = 8;

    logic [WIDTH-1:0] in0, in1, in2, in3;
    logic [1:0]       sel;
    logic [WIDTH-1:0] out;

    mux4to1 #(.WIDTH(WIDTH)) u_dut (.*);

    initial begin
        $display("=== MUX4TO1 Testbench ===");

        in0 = 8'hAA; in1 = 8'hBB; in2 = 8'hCC; in3 = 8'hDD;

        for (int s = 0; s < 4; s++) begin
            sel = s[1:0];
            #10;
            case (s)
                0: assert (out == 8'hAA) else $error("sel=%0d: expected AA, got %02h", s, out);
                1: assert (out == 8'hBB) else $error("sel=%0d: expected BB, got %02h", s, out);
                2: assert (out == 8'hCC) else $error("sel=%0d: expected CC, got %02h", s, out);
                3: assert (out == 8'hDD) else $error("sel=%0d: expected DD, got %02h", s, out);
            endcase
            $display("  sel=%0d -> out=0x%02h  PASS", s, out);
        end

        // Test with different data values
        in0 = 8'h00; in1 = 8'hFF; in2 = 8'h55; in3 = 8'hA5;
        for (int s = 0; s < 4; s++) begin
            sel = s[1:0];
            #10;
            $display("  sel=%0d -> out=0x%02h", s, out);
        end

        $display("=== MUX4TO1 All Tests Passed ===");
        $finish;
    end

endmodule
