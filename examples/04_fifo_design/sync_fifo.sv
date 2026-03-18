// ----------------------------------------------------------------------------
// Synchronous FIFO with Parameterized Depth and Width
// Demonstrates: dual-port RAM, pointer management, full/empty logic,
//               almost-full/almost-empty thresholds, overflow/underflow protection
// ----------------------------------------------------------------------------

module sync_fifo #(
    parameter int DATA_WIDTH    = 32,
    parameter int DEPTH         = 16,
    parameter int ALMOST_FULL   = DEPTH - 2,
    parameter int ALMOST_EMPTY  = 2
)(
    input  logic                    clk,
    input  logic                    rst_n,

    // Write interface
    input  logic                    wr_en,
    input  logic [DATA_WIDTH-1:0]   wr_data,
    output logic                    full,
    output logic                    almost_full,
    output logic                    overflow,

    // Read interface
    input  logic                    rd_en,
    output logic [DATA_WIDTH-1:0]   rd_data,
    output logic                    empty,
    output logic                    almost_empty,
    output logic                    underflow,

    // Status
    output logic [$clog2(DEPTH):0]  fill_level
);

    localparam int ADDR_WIDTH = $clog2(DEPTH);

    logic [DATA_WIDTH-1:0] mem [DEPTH];

    logic [ADDR_WIDTH:0] wr_ptr;    // Extra bit for full/empty distinction
    logic [ADDR_WIDTH:0] rd_ptr;
    logic [ADDR_WIDTH:0] count;

    wire wr_valid = wr_en && !full;
    wire rd_valid = rd_en && !empty;

    // Write logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr   <= '0;
            overflow <= 1'b0;
        end else begin
            overflow <= wr_en && full;
            if (wr_valid) begin
                mem[wr_ptr[ADDR_WIDTH-1:0]] <= wr_data;
                wr_ptr <= wr_ptr + 1'b1;
            end
        end
    end

    // Read logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_ptr    <= '0;
            underflow <= 1'b0;
            rd_data   <= '0;
        end else begin
            underflow <= rd_en && empty;
            if (rd_valid) begin
                rd_data <= mem[rd_ptr[ADDR_WIDTH-1:0]];
                rd_ptr  <= rd_ptr + 1'b1;
            end
        end
    end

    // Fill-level counter
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count <= '0;
        end else begin
            case ({wr_valid, rd_valid})
                2'b10:   count <= count + 1'b1;
                2'b01:   count <= count - 1'b1;
                default: count <= count;
            endcase
        end
    end

    // Status flags
    assign full         = (count == DEPTH);
    assign empty        = (count == '0);
    assign almost_full  = (count >= ALMOST_FULL);
    assign almost_empty = (count <= ALMOST_EMPTY) && !empty;
    assign fill_level   = count;

endmodule
