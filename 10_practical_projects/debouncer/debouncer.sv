// Button debouncer with edge detection.
//
// Waits for the input to be stable for DEBOUNCE_TICKS consecutive clock cycles
// before accepting the new level. Outputs clean level, rising edge, and falling edge.
//
// For a 100 MHz clock and 20 ms debounce window: DEBOUNCE_TICKS = 2_000_000

module debouncer #(
    parameter int DEBOUNCE_TICKS = 2_000_000
)(
    input  logic clk,
    input  logic rst_n,
    input  logic btn_in,       // raw button input (active high)
    output logic btn_out,      // debounced level
    output logic btn_rise,     // rising edge pulse
    output logic btn_fall      // falling edge pulse
);

    localparam int CNT_W = $clog2(DEBOUNCE_TICKS + 1);

    // Synchronize input to clock domain (metastability protection)
    logic btn_sync1, btn_sync2;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            btn_sync1 <= 1'b0;
            btn_sync2 <= 1'b0;
        end else begin
            btn_sync1 <= btn_in;
            btn_sync2 <= btn_sync1;
        end
    end

    // Debounce counter
    logic [CNT_W-1:0] count;
    logic              btn_stable;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count      <= '0;
            btn_stable <= 1'b0;
        end else if (btn_sync2 != btn_stable) begin
            if (count == CNT_W'(DEBOUNCE_TICKS - 1)) begin
                btn_stable <= btn_sync2;
                count      <= '0;
            end else begin
                count <= count + 1'b1;
            end
        end else begin
            count <= '0;
        end
    end

    // Edge detection
    logic btn_stable_prev;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            btn_stable_prev <= 1'b0;
        else
            btn_stable_prev <= btn_stable;
    end

    assign btn_out  = btn_stable;
    assign btn_rise =  btn_stable & ~btn_stable_prev;
    assign btn_fall = ~btn_stable &  btn_stable_prev;

endmodule
