// =============================================================================
// SpyGlass Lint Violations -- Demonstration File (BEFORE fixes)
//
// This file intentionally contains common Lint violations so you can see
// what SpyGlass flags. Each violation is annotated with its rule ID.
// See lint_violations_fixed.v for the corrected version.
// =============================================================================

module lint_violations (
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
// W_446: Signal declared but never assigned
// -------------------------------------------------------------------------
reg [7:0] spare_reg;           // never driven -- W_446

// -------------------------------------------------------------------------
// W_391: Inferred latch -- incomplete case statement
// -------------------------------------------------------------------------
reg [7:0] decoded;

always @(*) begin
    case (addr[1:0])
        2'b00: decoded = 8'h01;
        2'b01: decoded = 8'h02;
        2'b10: decoded = 8'h04;
        // missing 2'b11 -> latch inferred on 'decoded'
    endcase
end

// -------------------------------------------------------------------------
// W_391: Inferred latch -- incomplete if-else
// -------------------------------------------------------------------------
reg [7:0] priority_out;

always @(*) begin
    if (addr[3])
        priority_out = data_in;
    else if (addr[2])
        priority_out = ~data_in;
    // missing final else -> latch on 'priority_out'
end

// -------------------------------------------------------------------------
// W_116: Width mismatch in conditional expression
// -------------------------------------------------------------------------
wire [7:0] wide_val = 8'hFF;
wire [3:0] narrow_val = 4'hA;
wire [7:0] mux_out = wr_en ? wide_val : narrow_val;  // W_116

// -------------------------------------------------------------------------
// W_528: Combinational feedback loop
// -------------------------------------------------------------------------
wire loop_a, loop_b;
assign loop_a = loop_b & data_in[0];
assign loop_b = loop_a | data_in[1];   // loop: loop_a -> loop_b -> loop_a

// -------------------------------------------------------------------------
// W_164: Undriven instance port
// -------------------------------------------------------------------------
// Suppose 'sub_block' has ports: clk, rst_n, din[7:0], cfg[3:0], dout[7:0]
// Here we leave cfg unconnected.

// sub_block u_sub (
//     .clk   (clk),
//     .rst_n (rst_n),
//     .din   (data_in),
//     .cfg   (),           // W_164 -- undriven input port
//     .dout  (data_out)
// );

// -------------------------------------------------------------------------
// W_240: Incomplete sensitivity list (Verilog-95 style)
// -------------------------------------------------------------------------
reg [7:0] and_result;

always @(data_in)              // missing 'addr' in sensitivity list
    and_result = data_in & {4'b0, addr};

// -------------------------------------------------------------------------
// W_456: Signal assigned but never read
// -------------------------------------------------------------------------
reg [7:0] unused_result;

always @(posedge clk)
    unused_result <= data_in + 8'd1;   // result never used -- W_456

// -------------------------------------------------------------------------
// Non-synthesizable construct: initial block with delays
// -------------------------------------------------------------------------
reg [7:0] init_val;

initial begin
    init_val = 8'h00;
    #100;                     // delay -- not synthesizable
    init_val = 8'hAB;
end

// -------------------------------------------------------------------------
// W_213: Blocking assignment in sequential always block
// -------------------------------------------------------------------------
reg [7:0] seq_data;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        seq_data = 8'h00;    // should be <= (non-blocking)
    else
        seq_data = data_in;  // W_213: blocking in sequential block
end

// -------------------------------------------------------------------------
// W_468: Multi-driven signal
// -------------------------------------------------------------------------
reg [7:0] multi_driven;

always @(posedge clk)
    if (wr_en) multi_driven <= data_in;

always @(posedge clk)
    if (rd_en) multi_driven <= 8'h00;   // second driver -- W_468

// -------------------------------------------------------------------------
// Simple functional logic (to keep the module meaningful)
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
