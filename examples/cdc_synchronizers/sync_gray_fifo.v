//-----------------------------------------------------------------------------
// Synchronizer Library: Asynchronous FIFO with Gray-Code Pointers
//
// Use Case:
//   High-throughput data transfer between clock domains.
//   The most common CDC mechanism in real designs.
//
// How It Works:
//   - Dual-port RAM with independent read/write clocks
//   - Write pointer is in writer's clock domain (binary internally)
//   - Read pointer is in reader's clock domain (binary internally)
//   - To compare pointers across domains, each side converts its pointer
//     to Gray code and synchronizes the other side's Gray-coded pointer
//   - Gray code ensures at most 1-bit difference per increment,
//     making synchronization safe
//
// Full/Empty Detection:
//   - FIFO is empty when synced_wr_ptr_gray == rd_ptr_gray
//   - FIFO is full  when synced_rd_ptr_gray matches wr_ptr_gray with
//     the MSB inverted and MSB-1 inverted (Gray code full condition)
//
// Characteristics:
//   - Latency: 2 cycles (pointer synchronization delay)
//   - Throughput: 1 word per clock cycle (each domain)
//   - Depth: Must be power of 2 for Gray code to work correctly
//-----------------------------------------------------------------------------

module async_fifo #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 4   // Depth = 2^ADDR_WIDTH = 16
) (
    // Write side
    input  wire                   clk_wr,
    input  wire                   rst_wr_n,
    input  wire                   wr_en,
    input  wire [DATA_WIDTH-1:0]  wr_data,
    output wire                   full,

    // Read side
    input  wire                   clk_rd,
    input  wire                   rst_rd_n,
    input  wire                   rd_en,
    output wire [DATA_WIDTH-1:0]  rd_data,
    output wire                   empty
);

    localparam DEPTH = 1 << ADDR_WIDTH;

    //=========================================================================
    // Dual-Port RAM
    //=========================================================================
    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    // Write port (clk_wr domain)
    always @(posedge clk_wr) begin
        if (wr_en && !full)
            mem[wr_addr] <= wr_data;
    end

    // Read port (clk_rd domain)
    assign rd_data = mem[rd_addr];

    //=========================================================================
    // Write Pointer (clk_wr domain)
    //=========================================================================
    reg [ADDR_WIDTH:0] wr_ptr_bin;     // Extra bit for full/empty detection
    wire [ADDR_WIDTH:0] wr_ptr_gray;
    wire [ADDR_WIDTH-1:0] wr_addr;

    assign wr_addr = wr_ptr_bin[ADDR_WIDTH-1:0];
    assign wr_ptr_gray = wr_ptr_bin ^ (wr_ptr_bin >> 1);

    always @(posedge clk_wr or negedge rst_wr_n) begin
        if (!rst_wr_n)
            wr_ptr_bin <= {(ADDR_WIDTH+1){1'b0}};
        else if (wr_en && !full)
            wr_ptr_bin <= wr_ptr_bin + 1'b1;
    end

    //=========================================================================
    // Read Pointer (clk_rd domain)
    //=========================================================================
    reg [ADDR_WIDTH:0] rd_ptr_bin;
    wire [ADDR_WIDTH:0] rd_ptr_gray;
    wire [ADDR_WIDTH-1:0] rd_addr;

    assign rd_addr = rd_ptr_bin[ADDR_WIDTH-1:0];
    assign rd_ptr_gray = rd_ptr_bin ^ (rd_ptr_bin >> 1);

    always @(posedge clk_rd or negedge rst_rd_n) begin
        if (!rst_rd_n)
            rd_ptr_bin <= {(ADDR_WIDTH+1){1'b0}};
        else if (rd_en && !empty)
            rd_ptr_bin <= rd_ptr_bin + 1'b1;
    end

    //=========================================================================
    // Synchronize write pointer → read domain (for empty detection)
    //=========================================================================
    reg [ADDR_WIDTH:0] wr_ptr_gray_sync1, wr_ptr_gray_sync2;

    always @(posedge clk_rd or negedge rst_rd_n) begin
        if (!rst_rd_n) begin
            wr_ptr_gray_sync1 <= {(ADDR_WIDTH+1){1'b0}};
            wr_ptr_gray_sync2 <= {(ADDR_WIDTH+1){1'b0}};
        end else begin
            wr_ptr_gray_sync1 <= wr_ptr_gray;
            wr_ptr_gray_sync2 <= wr_ptr_gray_sync1;
        end
    end

    //=========================================================================
    // Synchronize read pointer → write domain (for full detection)
    //=========================================================================
    reg [ADDR_WIDTH:0] rd_ptr_gray_sync1, rd_ptr_gray_sync2;

    always @(posedge clk_wr or negedge rst_wr_n) begin
        if (!rst_wr_n) begin
            rd_ptr_gray_sync1 <= {(ADDR_WIDTH+1){1'b0}};
            rd_ptr_gray_sync2 <= {(ADDR_WIDTH+1){1'b0}};
        end else begin
            rd_ptr_gray_sync1 <= rd_ptr_gray;
            rd_ptr_gray_sync2 <= rd_ptr_gray_sync1;
        end
    end

    //=========================================================================
    // Full and Empty flags
    //=========================================================================
    // Empty: write pointer (synced to rd domain) equals read pointer
    assign empty = (wr_ptr_gray_sync2 == rd_ptr_gray);

    // Full: MSB and MSB-1 differ, remaining bits match (Gray code property)
    assign full = (wr_ptr_gray[ADDR_WIDTH]     != rd_ptr_gray_sync2[ADDR_WIDTH])     &&
                  (wr_ptr_gray[ADDR_WIDTH-1]   != rd_ptr_gray_sync2[ADDR_WIDTH-1])   &&
                  (wr_ptr_gray[ADDR_WIDTH-2:0] == rd_ptr_gray_sync2[ADDR_WIDTH-2:0]);

endmodule
