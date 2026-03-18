// =============================================================================
// SpyGlass CDC Violations -- Demonstration File (BEFORE fixes)
//
// This file contains a multi-clock-domain design with intentional CDC
// violations. Each violation is annotated with its SpyGlass rule ID.
// See cdc_violations_fixed.v for the corrected version.
// =============================================================================

module cdc_violations (
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
// VIOLATION 1: Ac_unsync01 -- Unsynchronized single-bit crossing
//
// 'flag_a' is in clk_a domain but read directly in clk_b domain.
// =========================================================================
reg flag_a;

always @(posedge clk_a or negedge rst_a_n)
    if (!rst_a_n)
        flag_a <= 1'b0;
    else
        flag_a <= valid_a;

always @(posedge clk_b or negedge rst_b_n)
    if (!rst_b_n)
        valid_b <= 1'b0;
    else
        valid_b <= flag_a;          // Ac_unsync01: no synchronizer!

// =========================================================================
// VIOLATION 2: Ac_multibit01 -- Multi-bit bus crossing without encoding
//
// An 8-bit data bus crosses from clk_a to clk_b without any protection.
// Individual bits may be sampled on different clk_b edges, corrupting data.
// =========================================================================
reg [7:0] data_a_reg;

always @(posedge clk_a or negedge rst_a_n)
    if (!rst_a_n)
        data_a_reg <= 8'h00;
    else if (valid_a)
        data_a_reg <= data_a;

always @(posedge clk_b or negedge rst_b_n)
    if (!rst_b_n)
        data_b <= 8'h00;
    else
        data_b <= data_a_reg;       // Ac_multibit01: raw bus crossing!

// =========================================================================
// VIOLATION 3: Ac_glitch01 -- Combinational logic before synchronizer
//
// Combinational output 'ctrl_combo' feeds across domains. Glitches on
// the combo logic can be captured by the destination flip-flop.
// =========================================================================
wire ctrl_combo = valid_a & data_a[0] & ~data_a[7];   // glitch-prone

reg ctrl_b_reg;
always @(posedge clk_b or negedge rst_b_n)
    if (!rst_b_n)
        ctrl_b_reg <= 1'b0;
    else
        ctrl_b_reg <= ctrl_combo;   // Ac_glitch01: combo feeds sync input

// =========================================================================
// VIOLATION 4: Ac_conv01 -- Convergence of independently synced CDC paths
//
// Two signals from clk_a are each synced independently into clk_c, then
// combined. They may arrive on different clk_c edges.
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

reg mode_c_s1, mode_c_s2;
reg enable_c_s1, enable_c_s2;

always @(posedge clk_c or negedge rst_c_n) begin
    if (!rst_c_n) begin
        mode_c_s1   <= 1'b0;
        mode_c_s2   <= 1'b0;
        enable_c_s1 <= 1'b0;
        enable_c_s2 <= 1'b0;
    end else begin
        mode_c_s1   <= mode_a;
        mode_c_s2   <= mode_c_s1;
        enable_c_s1 <= enable_a;
        enable_c_s2 <= enable_c_s1;
    end
end

// Convergence: both synced independently then combined
always @(posedge clk_c or negedge rst_c_n)
    if (!rst_c_n)
        status_c <= 4'h0;
    else
        status_c <= {2'b0, enable_c_s2, mode_c_s2};  // Ac_conv01

// =========================================================================
// VIOLATION 5: Ac_resetSync -- Reset from one domain used in another
//
// rst_a_n (clk_a domain) directly resets clk_b flip-flops.
// =========================================================================
reg [7:0] ctrl_reg_b;

always @(posedge clk_b or negedge rst_a_n)  // Ac_resetSync: rst_a_n is foreign
    if (!rst_a_n)
        ctrl_reg_b <= 8'h00;
    else
        ctrl_reg_b <= data_b;

// =========================================================================
// VIOLATION 6: Ac_unsync01 -- Multi-bit counter crossing (no Gray code)
//
// A 4-bit binary counter crosses from clk_a to clk_c directly.
// =========================================================================
reg [3:0] cnt_a;

always @(posedge clk_a or negedge rst_a_n)
    if (!rst_a_n)
        cnt_a <= 4'h0;
    else
        cnt_a <= cnt_a + 4'h1;

reg [3:0] cnt_c;
always @(posedge clk_c or negedge rst_c_n)
    if (!rst_c_n)
        cnt_c <= 4'h0;
    else
        cnt_c <= cnt_a;             // Ac_multibit01 + Ac_unsync01

endmodule
