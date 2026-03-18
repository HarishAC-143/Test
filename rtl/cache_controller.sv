// =============================================================================
// Direct-Mapped Write-Back Cache Controller
// Demonstrates: Cache architecture, tag comparison, dirty bit handling
// =============================================================================

module cache_controller #(
    parameter int ADDR_WIDTH    = 32,
    parameter int DATA_WIDTH    = 32,
    parameter int CACHE_SIZE    = 1024,  // bytes
    parameter int BLOCK_SIZE    = 16,    // bytes per cache line
    parameter int ASSOCIATIVITY = 1      // direct-mapped
) (
    input  logic                  clk,
    input  logic                  rst_n,

    // CPU interface
    input  logic [ADDR_WIDTH-1:0] cpu_addr,
    input  logic [DATA_WIDTH-1:0] cpu_wr_data,
    input  logic                  cpu_rd_en,
    input  logic                  cpu_wr_en,
    output logic [DATA_WIDTH-1:0] cpu_rd_data,
    output logic                  cpu_ready,

    // Memory interface
    output logic [ADDR_WIDTH-1:0] mem_addr,
    output logic [DATA_WIDTH-1:0] mem_wr_data,
    output logic                  mem_rd_en,
    output logic                  mem_wr_en,
    input  logic [DATA_WIDTH-1:0] mem_rd_data,
    input  logic                  mem_ready
);

    localparam int NUM_BLOCKS   = CACHE_SIZE / BLOCK_SIZE;
    localparam int WORDS_PER_BLK = BLOCK_SIZE / (DATA_WIDTH / 8);
    localparam int OFFSET_BITS  = $clog2(BLOCK_SIZE);
    localparam int INDEX_BITS   = $clog2(NUM_BLOCKS);
    localparam int TAG_BITS     = ADDR_WIDTH - INDEX_BITS - OFFSET_BITS;
    localparam int WORD_OFFSET_BITS = $clog2(WORDS_PER_BLK);

    // Address decomposition
    logic [TAG_BITS-1:0]         addr_tag;
    logic [INDEX_BITS-1:0]       addr_index;
    logic [WORD_OFFSET_BITS-1:0] addr_word_offset;

    assign addr_tag         = cpu_addr[ADDR_WIDTH-1 -: TAG_BITS];
    assign addr_index       = cpu_addr[OFFSET_BITS +: INDEX_BITS];
    assign addr_word_offset = cpu_addr[2 +: WORD_OFFSET_BITS];

    // Cache storage
    logic [TAG_BITS-1:0]    tag_array   [NUM_BLOCKS];
    logic                   valid_array [NUM_BLOCKS];
    logic                   dirty_array [NUM_BLOCKS];
    logic [DATA_WIDTH-1:0]  data_array  [NUM_BLOCKS][WORDS_PER_BLK];

    // Cache lookup
    logic tag_match;
    logic cache_hit;

    assign tag_match = (tag_array[addr_index] == addr_tag);
    assign cache_hit = valid_array[addr_index] && tag_match;

    // FSM
    typedef enum logic [2:0] {
        IDLE,
        TAG_CHECK,
        WRITEBACK,
        WRITEBACK_WAIT,
        ALLOCATE,
        ALLOCATE_WAIT,
        UPDATE
    } state_e;

    state_e state;

    logic [$clog2(WORDS_PER_BLK):0] word_count;
    logic [ADDR_WIDTH-1:0] saved_addr;
    logic [DATA_WIDTH-1:0] saved_wr_data;
    logic                  saved_wr_en;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state        <= IDLE;
            cpu_ready    <= 1'b1;
            cpu_rd_data  <= '0;
            mem_addr     <= '0;
            mem_wr_data  <= '0;
            mem_rd_en    <= 1'b0;
            mem_wr_en    <= 1'b0;
            word_count   <= '0;
            saved_addr   <= '0;
            saved_wr_data <= '0;
            saved_wr_en  <= 1'b0;

            for (int i = 0; i < NUM_BLOCKS; i++) begin
                valid_array[i] <= 1'b0;
                dirty_array[i] <= 1'b0;
                tag_array[i]   <= '0;
            end
        end else begin
            mem_rd_en <= 1'b0;
            mem_wr_en <= 1'b0;

            unique case (state)
                IDLE: begin
                    cpu_ready <= 1'b1;
                    if (cpu_rd_en || cpu_wr_en) begin
                        saved_addr    <= cpu_addr;
                        saved_wr_data <= cpu_wr_data;
                        saved_wr_en   <= cpu_wr_en;
                        cpu_ready     <= 1'b0;
                        state         <= TAG_CHECK;
                    end
                end

                TAG_CHECK: begin
                    if (cache_hit) begin
                        if (saved_wr_en) begin
                            data_array[addr_index][addr_word_offset] <= saved_wr_data;
                            dirty_array[addr_index] <= 1'b1;
                        end else begin
                            cpu_rd_data <= data_array[addr_index][addr_word_offset];
                        end
                        cpu_ready <= 1'b1;
                        state     <= IDLE;
                    end else if (valid_array[addr_index] && dirty_array[addr_index]) begin
                        // Need to write back dirty line first
                        word_count <= '0;
                        state      <= WRITEBACK;
                    end else begin
                        // Allocate new line
                        word_count <= '0;
                        state      <= ALLOCATE;
                    end
                end

                WRITEBACK: begin
                    mem_addr    <= {tag_array[addr_index], addr_index, {OFFSET_BITS{1'b0}}} +
                                  (word_count * (DATA_WIDTH/8));
                    mem_wr_data <= data_array[addr_index][word_count];
                    mem_wr_en   <= 1'b1;
                    state       <= WRITEBACK_WAIT;
                end

                WRITEBACK_WAIT: begin
                    if (mem_ready) begin
                        if (word_count == WORDS_PER_BLK - 1) begin
                            dirty_array[addr_index] <= 1'b0;
                            word_count <= '0;
                            state      <= ALLOCATE;
                        end else begin
                            word_count <= word_count + 1;
                            state      <= WRITEBACK;
                        end
                    end
                end

                ALLOCATE: begin
                    mem_addr  <= {addr_tag, addr_index, {OFFSET_BITS{1'b0}}} +
                                (word_count * (DATA_WIDTH/8));
                    mem_rd_en <= 1'b1;
                    state     <= ALLOCATE_WAIT;
                end

                ALLOCATE_WAIT: begin
                    if (mem_ready) begin
                        data_array[addr_index][word_count] <= mem_rd_data;
                        if (word_count == WORDS_PER_BLK - 1) begin
                            tag_array[addr_index]   <= addr_tag;
                            valid_array[addr_index] <= 1'b1;
                            dirty_array[addr_index] <= 1'b0;
                            state <= UPDATE;
                        end else begin
                            word_count <= word_count + 1;
                            state      <= ALLOCATE;
                        end
                    end
                end

                UPDATE: begin
                    if (saved_wr_en) begin
                        data_array[addr_index][addr_word_offset] <= saved_wr_data;
                        dirty_array[addr_index] <= 1'b1;
                    end else begin
                        cpu_rd_data <= data_array[addr_index][addr_word_offset];
                    end
                    cpu_ready <= 1'b1;
                    state     <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
