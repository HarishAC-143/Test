// PLL-Based Multi-Clock Design
// Demonstrates: PLL-derived clock constraints with derive_pll_clocks

module pll_top (
    input  wire        clk_50mhz,
    input  wire        rst_n,

    // Fast domain I/O (200 MHz)
    input  wire [15:0] fast_data_in,
    output reg  [15:0] fast_data_out,

    // Slow domain I/O (25 MHz)
    input  wire [7:0]  slow_data_in,
    output reg  [7:0]  slow_data_out,

    // Cross-domain status
    output reg         processing_done
);

    // PLL outputs (instantiation placeholder -- actual PLL IP would go here)
    wire clk_200mhz;    // PLL output c0: 200 MHz
    wire clk_25mhz;     // PLL output c1: 25 MHz
    wire clk_100mhz_90; // PLL output c2: 100 MHz, 90 deg phase
    wire pll_locked;

    // In real design, instantiate Altera PLL IP here:
    // my_pll pll_inst (
    //     .inclk0  (clk_50mhz),
    //     .c0      (clk_200mhz),
    //     .c1      (clk_25mhz),
    //     .c2      (clk_100mhz_90),
    //     .locked  (pll_locked)
    // );

    // Fast processing domain (200 MHz)
    reg [15:0] fast_pipe_1;
    reg [15:0] fast_pipe_2;

    always @(posedge clk_200mhz or negedge rst_n) begin
        if (!rst_n) begin
            fast_pipe_1   <= 16'd0;
            fast_pipe_2   <= 16'd0;
            fast_data_out <= 16'd0;
        end else begin
            fast_pipe_1   <= fast_data_in;
            fast_pipe_2   <= fast_pipe_1 + 16'd1;
            fast_data_out <= fast_pipe_2;
        end
    end

    // Slow control domain (25 MHz)
    reg [7:0] slow_reg;

    always @(posedge clk_25mhz or negedge rst_n) begin
        if (!rst_n) begin
            slow_reg      <= 8'd0;
            slow_data_out <= 8'd0;
        end else begin
            slow_reg      <= slow_data_in;
            slow_data_out <= slow_reg;
        end
    end

    // Cross-domain: done flag from fast domain to slow domain
    reg done_flag_fast;
    reg done_sync_meta, done_sync;

    always @(posedge clk_200mhz or negedge rst_n) begin
        if (!rst_n)
            done_flag_fast <= 1'b0;
        else
            done_flag_fast <= (fast_pipe_2 == 16'hFFFF);
    end

    always @(posedge clk_25mhz or negedge rst_n) begin
        if (!rst_n) begin
            done_sync_meta  <= 1'b0;
            done_sync       <= 1'b0;
            processing_done <= 1'b0;
        end else begin
            done_sync_meta  <= done_flag_fast;
            done_sync       <= done_sync_meta;
            processing_done <= done_sync;
        end
    end

endmodule
