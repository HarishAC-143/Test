// =============================================================================
// Synchronous FIFO with Parameterized Depth and Width
// Uses a circular buffer with read/write pointers.
// Provides full, empty, and programmable almost-full/almost-empty flags.
// =============================================================================

module sync_fifo #(
    parameter DATA_WIDTH   = 8,
    parameter DEPTH        = 16,
    parameter ALMOST_FULL  = DEPTH - 2,
    parameter ALMOST_EMPTY = 2,
    parameter ADDR_WIDTH   = $clog2(DEPTH)
) (
    input  logic                    clk,
    input  logic                    rst_n,

    // Write interface
    input  logic                    wr_en,
    input  logic [DATA_WIDTH-1:0]   wr_data,

    // Read interface
    input  logic                    rd_en,
    output logic [DATA_WIDTH-1:0]   rd_data,

    // Status flags
    output logic                    full,
    output logic                    empty,
    output logic                    almost_full,
    output logic                    almost_empty,
    output logic [ADDR_WIDTH:0]     count
);

    // Memory array
    logic [DATA_WIDTH-1:0] mem [DEPTH];

    // Pointers use an extra MSB to distinguish full from empty
    logic [ADDR_WIDTH:0] wr_ptr, rd_ptr;

    wire wr_valid = wr_en && !full;
    wire rd_valid = rd_en && !empty;

    // Write logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= '0;
        end else if (wr_valid) begin
            mem[wr_ptr[ADDR_WIDTH-1:0]] <= wr_data;
            wr_ptr <= wr_ptr + 1'b1;
        end
    end

    // Read logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_ptr <= '0;
        end else if (rd_valid) begin
            rd_ptr <= rd_ptr + 1'b1;
        end
    end

    assign rd_data = mem[rd_ptr[ADDR_WIDTH-1:0]];

    // Status signals
    assign count        = wr_ptr - rd_ptr;
    assign full         = (count == DEPTH[ADDR_WIDTH:0]);
    assign empty        = (count == '0);
    assign almost_full  = (count >= ALMOST_FULL[ADDR_WIDTH:0]);
    assign almost_empty = (count <= ALMOST_EMPTY[ADDR_WIDTH:0]) && !empty;

    // Assertions
    // synthesis translate_off
    always @(posedge clk) begin
        if (rst_n) begin
            assert (!(wr_en && full)) else
                $warning("Write attempted while FIFO is full");
            assert (!(rd_en && empty)) else
                $warning("Read attempted while FIFO is empty");
        end
    end
    // synthesis translate_on

endmodule
