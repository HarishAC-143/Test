// Testbench: Priority Encoder

`timescale 1ns / 1ps

module tb_priority_encoder;

    logic [7:0] req;
    logic [2:0] grant_idx;
    logic       valid;

    priority_encoder #(.IN_WIDTH(8)) u_dut (.*);

    initial begin
        $display("=== PRIORITY ENCODER Testbench ===");

        // No requests
        req = 8'b0000_0000;
        #10;
        assert (valid == 1'b0) else $error("No req: valid should be 0");
        $display("  req=%08b -> valid=%0b idx=%0d  PASS", req, valid, grant_idx);

        // Single bit requests
        for (int i = 0; i < 8; i++) begin
            req = 8'b1 << i;
            #10;
            assert (valid == 1'b1 && grant_idx == i[2:0])
                else $error("req=%08b: expected idx=%0d, got idx=%0d", req, i, grant_idx);
            $display("  req=%08b -> valid=%0b idx=%0d  PASS", req, valid, grant_idx);
        end

        // Multiple requests — highest index wins
        req = 8'b1010_0110;
        #10;
        assert (valid == 1'b1 && grant_idx == 3'd7)
            else $error("req=%08b: expected idx=7, got %0d", req, grant_idx);
        $display("  req=%08b -> valid=%0b idx=%0d  PASS", req, valid, grant_idx);

        req = 8'b0000_1111;
        #10;
        assert (valid == 1'b1 && grant_idx == 3'd3)
            else $error("req=%08b: expected idx=3, got %0d", req, grant_idx);
        $display("  req=%08b -> valid=%0b idx=%0d  PASS", req, valid, grant_idx);

        $display("=== PRIORITY ENCODER All Tests Passed ===");
        $finish;
    end

endmodule
