// =============================================================================
// SpyGlass Lint Violations -- FIXED Version
//
// Every violation from lint_violations.v has been corrected.
// Comments explain what changed and why.
// =============================================================================

module lint_violations_fixed (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [7:0]  data_in,
    input  wire [3:0]  addr,
    input  wire        wr_en,
    input  wire        rd_en,
    output reg  [7:0]  data_out,
    output wire        valid
);

// -------------------------------------------------------------------------
// FIX for W_446: Removed 'spare_reg' since it serves no purpose.
// If spares are intentional, waive the rule instead.
// -------------------------------------------------------------------------

// -------------------------------------------------------------------------
// FIX for W_391 (case): Added default branch
// -------------------------------------------------------------------------
reg [7:0] decoded;

always @(*) begin
    case (addr[1:0])
        2'b00:   decoded = 8'h01;
        2'b01:   decoded = 8'h02;
        2'b10:   decoded = 8'h04;
        default: decoded = 8'h00;    // covers 2'b11 -- no latch
    endcase
end

// -------------------------------------------------------------------------
// FIX for W_391 (if-else): Added final else
// -------------------------------------------------------------------------
reg [7:0] priority_out;

always @(*) begin
    if (addr[3])
        priority_out = data_in;
    else if (addr[2])
        priority_out = ~data_in;
    else
        priority_out = 8'h00;        // default -- no latch
end

// -------------------------------------------------------------------------
// FIX for W_116: Explicit width extension
// -------------------------------------------------------------------------
wire [7:0] wide_val = 8'hFF;
wire [3:0] narrow_val = 4'hA;
wire [7:0] mux_out = wr_en ? wide_val : {4'b0, narrow_val};

// -------------------------------------------------------------------------
// FIX for W_528: Broke the combinational loop by registering feedback
// -------------------------------------------------------------------------
reg loop_a_reg;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        loop_a_reg <= 1'b0;
    else
        loop_a_reg <= data_in[1] | (loop_a_reg & data_in[0]);
end

// -------------------------------------------------------------------------
// FIX for W_164: Connect or tie-off the undriven port
// -------------------------------------------------------------------------
// sub_block u_sub (
//     .clk   (clk),
//     .rst_n (rst_n),
//     .din   (data_in),
//     .cfg   (4'b0000),    // explicit tie-off
//     .dout  (data_out)
// );

// -------------------------------------------------------------------------
// FIX for W_240: Use @(*) for complete sensitivity list
// -------------------------------------------------------------------------
reg [7:0] and_result;

always @(*) begin             // automatic sensitivity -- no W_240
    and_result = data_in & {4'b0, addr};
end

// -------------------------------------------------------------------------
// FIX for W_456: Removed unused_result (or connect it somewhere)
// -------------------------------------------------------------------------

// -------------------------------------------------------------------------
// FIX for non-synthesizable construct: Removed initial block with delays.
// Use reset-based initialization instead.
// -------------------------------------------------------------------------

// -------------------------------------------------------------------------
// FIX for W_213: Use non-blocking assignments in sequential blocks
// -------------------------------------------------------------------------
reg [7:0] seq_data;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        seq_data <= 8'h00;
    else
        seq_data <= data_in;   // non-blocking -- correct
end

// -------------------------------------------------------------------------
// FIX for W_468: Merge into a single always block to avoid multi-driver
// -------------------------------------------------------------------------
reg [7:0] multi_driven;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        multi_driven <= 8'h00;
    else if (wr_en)
        multi_driven <= data_in;
    else if (rd_en)
        multi_driven <= 8'h00;
end

// -------------------------------------------------------------------------
// Main logic (unchanged from original)
// -------------------------------------------------------------------------
reg [7:0] mem [0:15];

always @(posedge clk) begin
    if (wr_en)
        mem[addr] <= data_in;
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        data_out <= 8'h00;
    else if (rd_en)
        data_out <= mem[addr];
end

assign valid = rd_en;

endmodule
