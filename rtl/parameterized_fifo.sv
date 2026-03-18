// =============================================================================
// Parameterized Synchronous FIFO
// Demonstrates: Parameterization, generate blocks, assertions, interfaces
// =============================================================================

module parameterized_fifo #(
    parameter int DATA_WIDTH = 8,
    parameter int DEPTH      = 16,
    parameter int ALMOST_FULL_THRESH  = DEPTH - 2,
    parameter int ALMOST_EMPTY_THRESH = 2
) (
    input  logic                  clk,
    input  logic                  rst_n,

    // Write interface
    input  logic                  wr_en,
    input  logic [DATA_WIDTH-1:0] wr_data,

    // Read interface
    input  logic                  rd_en,
    output logic [DATA_WIDTH-1:0] rd_data,

    // Status signals
    output logic                  full,
    output logic                  empty,
    output logic                  almost_full,
    output logic                  almost_empty,
    output logic [$clog2(DEPTH):0] count
);

    localparam int ADDR_WIDTH = $clog2(DEPTH);

    logic [DATA_WIDTH-1:0] mem [DEPTH];
    logic [ADDR_WIDTH:0]   wr_ptr, rd_ptr;
    logic [ADDR_WIDTH-1:0] wr_addr, rd_addr;

    assign wr_addr = wr_ptr[ADDR_WIDTH-1:0];
    assign rd_addr = rd_ptr[ADDR_WIDTH-1:0];

    assign full  = (wr_ptr[ADDR_WIDTH] != rd_ptr[ADDR_WIDTH]) &&
                   (wr_ptr[ADDR_WIDTH-1:0] == rd_ptr[ADDR_WIDTH-1:0]);
    assign empty = (wr_ptr == rd_ptr);

    assign count = wr_ptr - rd_ptr;
    assign almost_full  = (count >= ALMOST_FULL_THRESH);
    assign almost_empty = (count <= ALMOST_EMPTY_THRESH) && !empty;

    // Write logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= '0;
        end else if (wr_en && !full) begin
            mem[wr_addr] <= wr_data;
            wr_ptr <= wr_ptr + 1'b1;
        end
    end

    // Read logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_ptr  <= '0;
            rd_data <= '0;
        end else if (rd_en && !empty) begin
            rd_data <= mem[rd_addr];
            rd_ptr  <= rd_ptr + 1'b1;
        end
    end

    // =========================================================================
    // SystemVerilog Assertions (SVA) for verification
    // =========================================================================

    // Prevent write when full
    property no_write_when_full;
        @(posedge clk) disable iff (!rst_n)
        (full && wr_en) |-> $stable(wr_ptr);
    endproperty
    assert property (no_write_when_full)
        else $error("FIFO: Write attempted while full!");

    // Prevent read when empty
    property no_read_when_empty;
        @(posedge clk) disable iff (!rst_n)
        (empty && rd_en) |-> $stable(rd_ptr);
    endproperty
    assert property (no_read_when_empty)
        else $error("FIFO: Read attempted while empty!");

    // Count should never exceed DEPTH
    property count_in_range;
        @(posedge clk) disable iff (!rst_n)
        count <= DEPTH;
    endproperty
    assert property (count_in_range)
        else $error("FIFO: Count exceeded depth!");

endmodule
