// =============================================================================
// SpyGlass CDC Violations -- FIXED Version
//
// Every CDC violation from cdc_violations.v has been corrected.
// This file uses synchronizer modules from the synchronizers/ directory.
// =============================================================================

module cdc_violations_fixed (
    // Domain A
    input  wire        clk_a,
    input  wire        rst_a_n,
    input  wire [7:0]  data_a,
    input  wire        valid_a,

    // Domain B
    input  wire        clk_b,
    input  wire        rst_b_n,
    output reg  [7:0]  data_b,
    output reg         valid_b,

    // Domain C (slow clock)
    input  wire        clk_c,
    input  wire        rst_c_n,
    output reg  [3:0]  status_c
);

// =========================================================================
// FIX 1: Ac_unsync01 -- Use a 2-FF synchronizer for single-bit crossing
// =========================================================================
reg flag_a;

always @(posedge clk_a or negedge rst_a_n)
    if (!rst_a_n)
        flag_a <= 1'b0;
    else
        flag_a <= valid_a;

wire flag_a_sync;
sync_2ff #(.WIDTH(1)) u_sync_flag (
    .clk    (clk_b),
    .rst_n  (rst_b_n),
    .d      (flag_a),
    .q      (flag_a_sync)
);

always @(posedge clk_b or negedge rst_b_n)
    if (!rst_b_n)
        valid_b <= 1'b0;
    else
        valid_b <= flag_a_sync;     // safe: properly synchronized

// =========================================================================
// FIX 2: Ac_multibit01 -- Use MUX-qualified bus synchronizer
//
// Synchronize the valid signal first, then use it as a qualifier to
// sample the data bus only when it is stable.
// =========================================================================
reg [7:0] data_a_reg;
reg       data_valid_a;

always @(posedge clk_a or negedge rst_a_n)
    if (!rst_a_n) begin
        data_a_reg  <= 8'h00;
        data_valid_a <= 1'b0;
    end else begin
        data_valid_a <= valid_a;
        if (valid_a)
            data_a_reg <= data_a;
    end

wire data_valid_sync;
sync_2ff #(.WIDTH(1)) u_sync_dv (
    .clk    (clk_b),
    .rst_n  (rst_b_n),
    .d      (data_valid_a),
    .q      (data_valid_sync)
);

reg data_valid_sync_d;
always @(posedge clk_b or negedge rst_b_n)
    if (!rst_b_n)
        data_valid_sync_d <= 1'b0;
    else
        data_valid_sync_d <= data_valid_sync;

wire data_valid_pulse = data_valid_sync & ~data_valid_sync_d;

always @(posedge clk_b or negedge rst_b_n)
    if (!rst_b_n)
        data_b <= 8'h00;
    else if (data_valid_pulse)
        data_b <= data_a_reg;       // safe: data is stable when sampled

// =========================================================================
// FIX 3: Ac_glitch01 -- Register combinational output before crossing
// =========================================================================
reg ctrl_reg_a;

always @(posedge clk_a or negedge rst_a_n)
    if (!rst_a_n)
        ctrl_reg_a <= 1'b0;
    else
        ctrl_reg_a <= valid_a & data_a[0] & ~data_a[7];  // registered

wire ctrl_sync_b;
sync_2ff #(.WIDTH(1)) u_sync_ctrl (
    .clk    (clk_b),
    .rst_n  (rst_b_n),
    .d      (ctrl_reg_a),
    .q      (ctrl_sync_b)           // clean: no glitch
);

// =========================================================================
// FIX 4: Ac_conv01 -- Transfer related signals atomically
//
// Bundle mode_a and enable_a into a single bus and use a handshake or
// MUX-qualified transfer so they always arrive together.
// =========================================================================
reg mode_a, enable_a;

always @(posedge clk_a or negedge rst_a_n) begin
    if (!rst_a_n) begin
        mode_a   <= 1'b0;
        enable_a <= 1'b0;
    end else begin
        mode_a   <= data_a[0];
        enable_a <= data_a[1];
    end
end

wire [1:0] ctrl_bus_a = {enable_a, mode_a};
wire [1:0] ctrl_bus_c;

sync_bus_mux #(.WIDTH(2)) u_sync_bus (
    .clk_src  (clk_a),
    .rst_src_n(rst_a_n),
    .clk_dst  (clk_c),
    .rst_dst_n(rst_c_n),
    .d        (ctrl_bus_a),
    .q        (ctrl_bus_c)
);

always @(posedge clk_c or negedge rst_c_n)
    if (!rst_c_n)
        status_c <= 4'h0;
    else
        status_c <= {2'b0, ctrl_bus_c};   // bits transferred atomically

// =========================================================================
// FIX 5: Ac_resetSync -- Use a reset synchronizer
//
// Assert asynchronously, deassert synchronously in clk_b domain.
// =========================================================================
wire rst_b_sync_n;

reset_sync u_rst_sync (
    .clk      (clk_b),
    .rst_in_n (rst_a_n),
    .rst_out_n(rst_b_sync_n)
);

reg [7:0] ctrl_reg_b;

always @(posedge clk_b or negedge rst_b_sync_n)
    if (!rst_b_sync_n)
        ctrl_reg_b <= 8'h00;
    else
        ctrl_reg_b <= data_b;       // safe: reset is domain-local

// =========================================================================
// FIX 6: Ac_multibit01 + Ac_unsync01 -- Gray-code the counter
// =========================================================================
reg [3:0] cnt_a;

always @(posedge clk_a or negedge rst_a_n)
    if (!rst_a_n)
        cnt_a <= 4'h0;
    else
        cnt_a <= cnt_a + 4'h1;

wire [3:0] cnt_gray_a = cnt_a ^ (cnt_a >> 1);   // binary -> Gray

wire [3:0] cnt_gray_c;

sync_2ff #(.WIDTH(4)) u_sync_cnt (
    .clk    (clk_c),
    .rst_n  (rst_c_n),
    .d      (cnt_gray_a),
    .q      (cnt_gray_c)
);

// Gray -> binary conversion in destination domain
wire [3:0] cnt_c;
assign cnt_c[3] = cnt_gray_c[3];
assign cnt_c[2] = cnt_gray_c[3] ^ cnt_gray_c[2];
assign cnt_c[1] = cnt_c[2]      ^ cnt_gray_c[1];
assign cnt_c[0] = cnt_c[1]      ^ cnt_gray_c[0];

endmodule
