// Synchronous FIFO
// Single-clock FIFO with parameterized depth and width.
// Uses a counter-based approach for full/empty detection (simple and reliable).

module sync_fifo #(
    parameter DATA_WIDTH = 8,
    parameter DEPTH      = 16,
    parameter ADDR_WIDTH = $clog2(DEPTH)
)(
    input  logic                    clk,
    input  logic                    rst_n,
    // Write port
    input  logic                    wr_en,
    input  logic [DATA_WIDTH-1:0]   wr_data,
    // Read port
    input  logic                    rd_en,
    output logic [DATA_WIDTH-1:0]   rd_data,
    // Status
    output logic                    full,
    output logic                    empty,
    output logic [ADDR_WIDTH:0]     count
);

    logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    logic [ADDR_WIDTH-1:0] wr_ptr, rd_ptr;

    assign full  = (count == DEPTH[ADDR_WIDTH:0]);
    assign empty = (count == '0);

    // Write pointer and memory
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= '0;
        end else if (wr_en && !full) begin
            mem[wr_ptr] <= wr_data;
            wr_ptr      <= wr_ptr + 1'b1;
        end
    end

    // Read pointer and data
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_ptr  <= '0;
            rd_data <= '0;
        end else if (rd_en && !empty) begin
            rd_data <= mem[rd_ptr];
            rd_ptr  <= rd_ptr + 1'b1;
        end
    end

    // Element counter
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count <= '0;
        end else begin
            case ({wr_en && !full, rd_en && !empty})
                2'b10:   count <= count + 1'b1;
                2'b01:   count <= count - 1'b1;
                default: ;  // simultaneous or neither: count unchanged
            endcase
        end
    end

endmodule
