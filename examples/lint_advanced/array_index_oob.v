//-----------------------------------------------------------------------------
// Example: Array Index Out of Bounds
//
// SpyGlass Rules Triggered:
//   W_362  - Array index may go out of bounds
//   W_164a - Width mismatch in index expression
//
// Out-of-bounds array access leads to undefined behavior in simulation
// and potentially unpredictable hardware behavior after synthesis.
//-----------------------------------------------------------------------------

module array_index_bad (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [3:0]  addr,       // 4-bit address → range 0..15
    input  wire [7:0]  wr_data,
    input  wire        wr_en,
    output reg  [7:0]  rd_data
);

    reg [7:0] memory [0:7];  // Only 8 entries (indices 0..7)

    // BUG: addr can be 0..15, but memory only has 0..7
    // Accessing memory[8]..memory[15] is out of bounds — W_362
    always @(posedge clk) begin
        if (wr_en)
            memory[addr] <= wr_data;     // OOB when addr > 7
    end

    always @(posedge clk) begin
        rd_data <= memory[addr];         // OOB when addr > 7
    end

endmodule


module array_index_good (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [3:0]  addr,
    input  wire [7:0]  wr_data,
    input  wire        wr_en,
    output reg  [7:0]  rd_data
);

    reg [7:0] memory [0:15];  // FIX: Size matches address range (2^4 = 16)

    always @(posedge clk) begin
        if (wr_en)
            memory[addr] <= wr_data;
    end

    always @(posedge clk) begin
        rd_data <= memory[addr];
    end

endmodule


module array_index_good_v2 (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [3:0]  addr,
    input  wire [7:0]  wr_data,
    input  wire        wr_en,
    output reg  [7:0]  rd_data
);

    reg [7:0] memory [0:7];

    // Alternative fix: mask the address to valid range
    wire [2:0] safe_addr = addr[2:0];

    always @(posedge clk) begin
        if (wr_en && (addr < 4'd8))
            memory[safe_addr] <= wr_data;
    end

    always @(posedge clk) begin
        if (addr < 4'd8)
            rd_data <= memory[safe_addr];
        else
            rd_data <= 8'b0;
    end

endmodule
