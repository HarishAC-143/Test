// Testbench for Traffic Light Controller
// Uses fast timer settings for simulation

module tb_traffic_light;

    // Fast timer parameters for simulation
    localparam int CLK_FREQ_HZ    = 1000;  // 1 kHz for fast sim
    localparam int GREEN_TIME_MS  = 10;
    localparam int YELLOW_TIME_MS = 3;
    localparam int PED_TIME_MS    = 7;
    localparam int ALL_RED_MS     = 1;

    logic       clk;
    logic       rst_n;
    logic       sensor_side_road;
    logic       ped_request;
    logic       emergency;
    logic [2:0] main_light;
    logic [2:0] side_light;
    logic [1:0] ped_light;
    logic       ped_buzzer;

    int error_count = 0;

    traffic_light_controller #(
        .CLK_FREQ_HZ   (CLK_FREQ_HZ),
        .GREEN_TIME_MS  (GREEN_TIME_MS),
        .YELLOW_TIME_MS (YELLOW_TIME_MS),
        .PED_TIME_MS    (PED_TIME_MS),
        .ALL_RED_MS     (ALL_RED_MS)
    ) dut (.*);

    initial begin
        clk = 0;
        forever #500_000 clk = ~clk;  // 1 kHz = 500us half period
    end

    function string decode_light(input logic [2:0] light);
        case (light)
            3'b100:  return "GREEN ";
            3'b010:  return "YELLOW";
            3'b001:  return "RED   ";
            default: return "UNKNWN";
        endcase
    endfunction

    function string decode_ped(input logic [1:0] ped);
        case (ped)
            2'b10:   return "WALK     ";
            2'b01:   return "DONT_WALK";
            default: return "UNKNOWN  ";
        endcase
    endfunction

    task automatic wait_ms(input int ms);
        repeat (ms) begin
            repeat (CLK_FREQ_HZ / 1000) @(posedge clk);
        end
    endtask

    task automatic display_state();
        $display("  Time=%0t  Main=%s  Side=%s  Ped=%s  Buzzer=%b",
                 $time,
                 decode_light(main_light),
                 decode_light(side_light),
                 decode_ped(ped_light),
                 ped_buzzer);
    endtask

    initial begin
        $display("=== Traffic Light Controller Testbench ===");
        $display("");

        rst_n            = 0;
        sensor_side_road = 0;
        ped_request      = 0;
        emergency        = 0;

        repeat (3) @(posedge clk);
        rst_n = 1;

        // Test 1: Initial state should be MAIN_GREEN
        @(posedge clk);
        $display("[Test 1] Initial state after reset:");
        display_state();
        if (main_light !== 3'b100) begin
            $error("[FAIL] Expected main=GREEN after reset");
            error_count++;
        end else begin
            $display("[PASS] Main road starts GREEN");
        end

        // Test 2: Stay green when no side-road sensor
        $display("");
        $display("[Test 2] Main stays green without side-road sensor:");
        wait_ms(GREEN_TIME_MS + 5);
        display_state();
        if (main_light !== 3'b100) begin
            $error("[FAIL] Main should stay GREEN without sensor");
            error_count++;
        end else begin
            $display("[PASS] Main stays GREEN without side-road traffic");
        end

        // Test 3: Transition to side road when sensor activated
        $display("");
        $display("[Test 3] Transition sequence with side-road sensor:");
        sensor_side_road = 1;
        wait_ms(2);
        display_state();  // Should transition to yellow

        wait_ms(YELLOW_TIME_MS + 1);
        display_state();  // Should be all red

        wait_ms(ALL_RED_MS + 1);
        display_state();  // Should be side green
        if (side_light !== 3'b100) begin
            $error("[FAIL] Expected side=GREEN after transition");
            error_count++;
        end else begin
            $display("[PASS] Side road gets GREEN");
        end

        sensor_side_road = 0;

        // Let side road complete its full cycle back to main green
        wait_ms(GREEN_TIME_MS + YELLOW_TIME_MS + ALL_RED_MS + 5);

        // Test 4: Pedestrian request
        $display("");
        $display("[Test 4] Pedestrian crossing request:");
        ped_request = 1;
        @(posedge clk);
        ped_request = 0;

        wait_ms(GREEN_TIME_MS + YELLOW_TIME_MS + ALL_RED_MS + 2);
        display_state();
        if (ped_light !== 2'b10) begin
            $error("[FAIL] Expected WALK signal");
            error_count++;
        end else begin
            $display("[PASS] Pedestrian gets WALK signal");
        end

        if (ped_buzzer !== 1'b1) begin
            $error("[FAIL] Expected buzzer active");
            error_count++;
        end else begin
            $display("[PASS] Pedestrian buzzer active");
        end

        // Wait for ped cycle to complete
        wait_ms(PED_TIME_MS + YELLOW_TIME_MS + ALL_RED_MS + 5);

        // Test 5: Emergency override
        $display("");
        $display("[Test 5] Emergency vehicle override:");
        emergency = 1;
        wait_ms(2);
        display_state();
        if (main_light !== 3'b001 || side_light !== 3'b001) begin
            $error("[FAIL] Expected all RED during emergency");
            error_count++;
        end else begin
            $display("[PASS] All lights RED during emergency");
        end

        // Release emergency
        wait_ms(5);
        emergency = 0;
        wait_ms(2);
        display_state();
        if (main_light !== 3'b100) begin
            $error("[FAIL] Expected return to MAIN_GREEN after emergency");
            error_count++;
        end else begin
            $display("[PASS] Returns to MAIN_GREEN after emergency");
        end

        $display("");
        if (error_count == 0)
            $display("ALL TESTS PASSED");
        else
            $display("%0d FAILURES DETECTED", error_count);

        $finish;
    end

endmodule
