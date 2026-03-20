// ============================================================================
// Synchronous FIFO
// ============================================================================
// A single-clock FIFO using a circular buffer with separate read and write
// pointers. Features:
//   - Parameterized width and depth
//   - Full, empty, and count status signals
//   - Almost-full / almost-empty thresholds
//   - Simultaneous read/write support
//
// The extra MSB in the pointers distinguishes full from empty when the
// address bits match.
// ============================================================================

module sync_fifo #(
    parameter int WIDTH        = 8,
    parameter int DEPTH        = 16,
    parameter int ALMOST_FULL  = DEPTH - 2,
    parameter int ALMOST_EMPTY = 2
)(
    input  logic             clk,
    input  logic             rst_n,

    // Write port
    input  logic             wr_en,
    input  logic [WIDTH-1:0] wr_data,

    // Read port
    input  logic             rd_en,
    output logic [WIDTH-1:0] rd_data,

    // Status
    output logic             full,
    output logic             empty,
    output logic             almost_full,
    output logic             almost_empty,
    output logic [$clog2(DEPTH):0] count
);

    localparam int ADDR_W = $clog2(DEPTH);

    logic [WIDTH-1:0] mem [DEPTH];
    logic [ADDR_W:0]  wr_ptr, rd_ptr;

    wire do_write = wr_en && !full;
    wire do_read  = rd_en && !empty;

    // Status flags
    assign full         = (count == DEPTH[$clog2(DEPTH):0]);
    assign empty        = (count == '0);
    assign almost_full  = (count >= ALMOST_FULL[$clog2(DEPTH):0]);
    assign almost_empty = (count <= ALMOST_EMPTY[$clog2(DEPTH):0]);

    // Write pointer and memory
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            wr_ptr <= '0;
        else if (do_write) begin
            mem[wr_ptr[ADDR_W-1:0]] <= wr_data;
            wr_ptr <= wr_ptr + 1'b1;
        end
    end

    // Read pointer
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            rd_ptr <= '0;
        else if (do_read)
            rd_ptr <= rd_ptr + 1'b1;
    end

    // Combinational read output
    assign rd_data = mem[rd_ptr[ADDR_W-1:0]];

    // Count tracking
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            count <= '0;
        else begin
            unique case ({do_write, do_read})
                2'b10:   count <= count + 1'b1;
                2'b01:   count <= count - 1'b1;
                default: count <= count;
            endcase
        end
    end

endmodule
