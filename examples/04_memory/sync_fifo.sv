// Synchronous FIFO (First-In First-Out) Buffer

module sync_fifo #(
    parameter DATA_WIDTH = 8,
    parameter DEPTH      = 16
)(
    input  logic                   clk,
    input  logic                   rst_n,
    input  logic                   wr_en,
    input  logic                   rd_en,
    input  logic [DATA_WIDTH-1:0]  wr_data,
    output logic [DATA_WIDTH-1:0]  rd_data,
    output logic                   full,
    output logic                   empty,
    output logic [$clog2(DEPTH):0] count
);

    localparam ADDR_WIDTH = $clog2(DEPTH);

    logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    logic [ADDR_WIDTH-1:0] wr_ptr, rd_ptr;
    logic [ADDR_WIDTH:0]   fifo_count;

    assign count = fifo_count;
    assign full  = (fifo_count == DEPTH);
    assign empty = (fifo_count == '0);

    // Write logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            wr_ptr <= '0;
        else if (wr_en && !full) begin
            mem[wr_ptr] <= wr_data;
            wr_ptr      <= wr_ptr + 1'b1;
        end
    end

    // Read logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_ptr  <= '0;
            rd_data <= '0;
        end else if (rd_en && !empty) begin
            rd_data <= mem[rd_ptr];
            rd_ptr  <= rd_ptr + 1'b1;
        end
    end

    // Count tracking
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            fifo_count <= '0;
        else begin
            case ({wr_en && !full, rd_en && !empty})
                2'b10:   fifo_count <= fifo_count + 1'b1;
                2'b01:   fifo_count <= fifo_count - 1'b1;
                default: fifo_count <= fifo_count;
            endcase
        end
    end

endmodule
