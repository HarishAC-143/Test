// Synchronous FIFO
// Single clock domain FIFO using dual-port RAM and read/write pointers.
// Commonly used for data buffering and rate matching within a clock domain.

module sync_fifo #(
    parameter int DATA_WIDTH = 8,
    parameter int DEPTH      = 16,
    parameter int ADDR_WIDTH = $clog2(DEPTH)
) (
    input  logic                  clk,
    input  logic                  rst_n,

    // Write interface
    input  logic                  wr_en,
    input  logic [DATA_WIDTH-1:0] wr_data,
    output logic                  full,

    // Read interface
    input  logic                  rd_en,
    output logic [DATA_WIDTH-1:0] rd_data,
    output logic                  empty,

    // Status
    output logic [ADDR_WIDTH:0]   fill_level
);

    // Memory array
    logic [DATA_WIDTH-1:0] mem [DEPTH];

    // Pointers (extra bit for full/empty detection)
    logic [ADDR_WIDTH:0] wr_ptr;
    logic [ADDR_WIDTH:0] rd_ptr;

    // Derived signals
    wire wr_valid = wr_en && !full;
    wire rd_valid = rd_en && !empty;

    // Write pointer and memory write
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= '0;
        end else if (wr_valid) begin
            mem[wr_ptr[ADDR_WIDTH-1:0]] <= wr_data;
            wr_ptr <= wr_ptr + 1'b1;
        end
    end

    // Read pointer
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            rd_ptr <= '0;
        else if (rd_valid)
            rd_ptr <= rd_ptr + 1'b1;
    end

    // Read data (combinational read from RAM)
    assign rd_data = mem[rd_ptr[ADDR_WIDTH-1:0]];

    // Full: pointers match but MSBs differ
    assign full  = (wr_ptr[ADDR_WIDTH] != rd_ptr[ADDR_WIDTH]) &&
                   (wr_ptr[ADDR_WIDTH-1:0] == rd_ptr[ADDR_WIDTH-1:0]);

    // Empty: pointers match exactly
    assign empty = (wr_ptr == rd_ptr);

    // Fill level
    assign fill_level = wr_ptr - rd_ptr;

    // --- Assertions for verification ---
    // synthesis translate_off
    assert property (@(posedge clk) disable iff (!rst_n)
        !(wr_en && full))
        else $error("FIFO: Write while full!");

    assert property (@(posedge clk) disable iff (!rst_n)
        !(rd_en && empty))
        else $error("FIFO: Read while empty!");

    assert property (@(posedge clk) disable iff (!rst_n)
        fill_level <= DEPTH)
        else $error("FIFO: Fill level exceeded depth!");
    // synthesis translate_on

endmodule
