// Testbench: 3-to-8 Decoder

`timescale 1ns / 1ps

module tb_decoder_3to8;

    logic [2:0] in;
    logic       enable;
    logic [7:0] out;

    decoder_3to8 u_dut (.*);

    initial begin
        $display("=== DECODER 3-to-8 Testbench ===");

        // Test with enable = 0 — all outputs should be 0
        enable = 1'b0;
        for (int i = 0; i < 8; i++) begin
            in = i[2:0];
            #10;
            assert (out == 8'h00)
                else $error("Enable=0, in=%0d: expected 00, got %02h", i, out);
        end
        $display("  Enable=0: all outputs deasserted  PASS");

        // Test with enable = 1 — exactly one output asserted
        enable = 1'b1;
        for (int i = 0; i < 8; i++) begin
            in = i[2:0];
            #10;
            assert (out == (8'b1 << i))
                else $error("Enable=1, in=%0d: expected %08b, got %08b", i, 8'b1 << i, out);
            $display("  in=%0d -> out=%08b  PASS", i, out);
        end

        $display("=== DECODER 3-to-8 All Tests Passed ===");
        $finish;
    end

endmodule
