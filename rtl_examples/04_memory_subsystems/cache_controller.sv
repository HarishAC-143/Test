// =============================================================================
// Direct-Mapped Cache Controller
// Implements a simple direct-mapped write-back cache.
// Demonstrates tag/index/offset decomposition and state machine control.
// =============================================================================

module cache_controller #(
    parameter ADDR_WIDTH   = 32,
    parameter DATA_WIDTH   = 32,
    parameter CACHE_LINES  = 256,
    parameter LINE_SIZE    = 4,    // Words per cache line
    parameter INDEX_WIDTH  = $clog2(CACHE_LINES),
    parameter OFFSET_WIDTH = $clog2(LINE_SIZE),
    parameter TAG_WIDTH    = ADDR_WIDTH - INDEX_WIDTH - OFFSET_WIDTH - 2  // -2 for byte offset
) (
    input  logic                    clk,
    input  logic                    rst_n,

    // CPU interface
    input  logic                    cpu_req,
    input  logic                    cpu_wr,
    input  logic [ADDR_WIDTH-1:0]   cpu_addr,
    input  logic [DATA_WIDTH-1:0]   cpu_wdata,
    output logic [DATA_WIDTH-1:0]   cpu_rdata,
    output logic                    cpu_ready,

    // Memory interface
    output logic                    mem_req,
    output logic                    mem_wr,
    output logic [ADDR_WIDTH-1:0]   mem_addr,
    output logic [DATA_WIDTH-1:0]   mem_wdata,
    input  logic [DATA_WIDTH-1:0]   mem_rdata,
    input  logic                    mem_ready
);

    // Address field extraction
    logic [TAG_WIDTH-1:0]    tag;
    logic [INDEX_WIDTH-1:0]  index;
    logic [OFFSET_WIDTH-1:0] offset;

    assign tag    = cpu_addr[ADDR_WIDTH-1 : INDEX_WIDTH + OFFSET_WIDTH + 2];
    assign index  = cpu_addr[INDEX_WIDTH + OFFSET_WIDTH + 1 : OFFSET_WIDTH + 2];
    assign offset = cpu_addr[OFFSET_WIDTH + 1 : 2];

    // Cache storage
    logic [TAG_WIDTH-1:0]   tag_array   [CACHE_LINES];
    logic                   valid_array [CACHE_LINES];
    logic                   dirty_array [CACHE_LINES];
    logic [DATA_WIDTH-1:0]  data_array  [CACHE_LINES][LINE_SIZE];

    // FSM states
    typedef enum logic [2:0] {
        IDLE       = 3'b000,
        COMPARE    = 3'b001,
        WRITEBACK  = 3'b010,
        ALLOCATE   = 3'b011,
        WB_WAIT    = 3'b100,
        ALLOC_WAIT = 3'b101
    } state_e;

    state_e state, next_state;

    logic hit;
    logic [OFFSET_WIDTH-1:0] word_counter;

    assign hit = valid_array[index] && (tag_array[index] == tag);

    // State register
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= IDLE;
        else
            state <= next_state;
    end

    // Word counter for multi-word line transfers
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            word_counter <= '0;
        end else if (state == IDLE) begin
            word_counter <= '0;
        end else if ((state == WB_WAIT || state == ALLOC_WAIT) && mem_ready) begin
            word_counter <= word_counter + 1'b1;
        end
    end

    // Next state logic
    always_comb begin
        next_state = state;

        case (state)
            IDLE: begin
                if (cpu_req)
                    next_state = COMPARE;
            end

            COMPARE: begin
                if (hit)
                    next_state = IDLE;
                else if (dirty_array[index])
                    next_state = WRITEBACK;
                else
                    next_state = ALLOCATE;
            end

            WRITEBACK: begin
                next_state = WB_WAIT;
            end

            WB_WAIT: begin
                if (mem_ready && word_counter == OFFSET_WIDTH'(LINE_SIZE - 1))
                    next_state = ALLOCATE;
            end

            ALLOCATE: begin
                next_state = ALLOC_WAIT;
            end

            ALLOC_WAIT: begin
                if (mem_ready && word_counter == OFFSET_WIDTH'(LINE_SIZE - 1))
                    next_state = COMPARE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Datapath
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < CACHE_LINES; i++) begin
                valid_array[i] <= 1'b0;
                dirty_array[i] <= 1'b0;
            end
        end else begin
            case (state)
                COMPARE: begin
                    if (hit && cpu_wr) begin
                        data_array[index][offset] <= cpu_wdata;
                        dirty_array[index]        <= 1'b1;
                    end
                end

                ALLOC_WAIT: begin
                    if (mem_ready) begin
                        data_array[index][word_counter] <= mem_rdata;
                        if (word_counter == OFFSET_WIDTH'(LINE_SIZE - 1)) begin
                            tag_array[index]   <= tag;
                            valid_array[index] <= 1'b1;
                            dirty_array[index] <= 1'b0;
                        end
                    end
                end

                default: ;
            endcase
        end
    end

    // CPU interface
    assign cpu_rdata = data_array[index][offset];
    assign cpu_ready = (state == COMPARE) && hit;

    // Memory interface
    assign mem_req   = (state == WB_WAIT) || (state == ALLOC_WAIT);
    assign mem_wr    = (state == WB_WAIT);
    assign mem_wdata = data_array[index][word_counter];
    assign mem_addr  = (state == WB_WAIT) ?
                       {tag_array[index], index, word_counter, 2'b00} :
                       {tag, index, word_counter, 2'b00};

endmodule
