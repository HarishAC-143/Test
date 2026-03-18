// Synchronous FIFO with parameterized width, depth, and status thresholds.
// Designed to infer block RAM (M10K/M20K) in Altera FPGAs.

module fifo_sync #(
    parameter int DATA_WIDTH          = 8,
    parameter int DEPTH               = 16,
    parameter int ALMOST_FULL_THRESH  = DEPTH - 2,
    parameter int ALMOST_EMPTY_THRESH = 2
)(
    input  logic                    clk,
    input  logic                    rst_n,
    input  logic                    wr_en,
    input  logic                    rd_en,
    input  logic [DATA_WIDTH-1:0]   wr_data,
    output logic [DATA_WIDTH-1:0]   rd_data,
    output logic                    full,
    output logic                    empty,
    output logic                    almost_full,
    output logic                    almost_empty,
    output logic [$clog2(DEPTH):0]  count
);

    localparam int ADDR_WIDTH = $clog2(DEPTH);

    // Memory array — infers block RAM when DEPTH >= 16
    logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    // Pointers
    logic [ADDR_WIDTH:0] wr_ptr;
    logic [ADDR_WIDTH:0] rd_ptr;

    // Internal write/read enables (gated by full/empty)
    logic wr_valid;
    logic rd_valid;

    assign wr_valid = wr_en & ~full;
    assign rd_valid = rd_en & ~empty;

    // Write pointer
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            wr_ptr <= '0;
        else if (wr_valid)
            wr_ptr <= wr_ptr + 1'b1;
    end

    // Read pointer
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            rd_ptr <= '0;
        else if (rd_valid)
            rd_ptr <= rd_ptr + 1'b1;
    end

    // Memory write
    always_ff @(posedge clk) begin
        if (wr_valid)
            mem[wr_ptr[ADDR_WIDTH-1:0]] <= wr_data;
    end

    // Memory read (registered output for block RAM inference)
    always_ff @(posedge clk) begin
        if (rd_valid)
            rd_data <= mem[rd_ptr[ADDR_WIDTH-1:0]];
    end

    // Count tracking
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
    assign full         = (count == DEPTH[$clog2(DEPTH):0]);
    assign empty        = (count == '0);
    assign almost_full  = (count >= ALMOST_FULL_THRESH[$clog2(DEPTH):0]);
    assign almost_empty = (count <= ALMOST_EMPTY_THRESH[$clog2(DEPTH):0]) & ~empty;

endmodule
