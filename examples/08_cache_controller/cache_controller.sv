// Direct-Mapped Cache Controller
// Implements a simple direct-mapped cache with write-back policy.
// Parameterized cache size, line size, and address width.

module cache_controller #(
    parameter int ADDR_WIDTH  = 32,
    parameter int DATA_WIDTH  = 32,
    parameter int CACHE_LINES = 64,
    parameter int LINE_SIZE   = 4,    // Words per cache line
    localparam int INDEX_WIDTH = $clog2(CACHE_LINES),
    localparam int OFFSET_WIDTH = $clog2(LINE_SIZE),
    localparam int TAG_WIDTH   = ADDR_WIDTH - INDEX_WIDTH - OFFSET_WIDTH - 2
) (
    input  logic                   clk,
    input  logic                   rst_n,

    // CPU interface
    input  logic                   cpu_req,
    input  logic                   cpu_wr,
    input  logic [ADDR_WIDTH-1:0]  cpu_addr,
    input  logic [DATA_WIDTH-1:0]  cpu_wdata,
    output logic [DATA_WIDTH-1:0]  cpu_rdata,
    output logic                   cpu_ready,

    // Memory interface
    output logic                   mem_req,
    output logic                   mem_wr,
    output logic [ADDR_WIDTH-1:0]  mem_addr,
    output logic [DATA_WIDTH-1:0]  mem_wdata,
    input  logic [DATA_WIDTH-1:0]  mem_rdata,
    input  logic                   mem_ready
);

    // Address field extraction
    logic [TAG_WIDTH-1:0]    addr_tag;
    logic [INDEX_WIDTH-1:0]  addr_index;
    logic [OFFSET_WIDTH-1:0] addr_offset;

    assign addr_tag    = cpu_addr[ADDR_WIDTH-1 : INDEX_WIDTH + OFFSET_WIDTH + 2];
    assign addr_index  = cpu_addr[INDEX_WIDTH + OFFSET_WIDTH + 2 - 1 : OFFSET_WIDTH + 2];
    assign addr_offset = cpu_addr[OFFSET_WIDTH + 2 - 1 : 2];

    // Cache storage
    logic                       valid_array [CACHE_LINES];
    logic                       dirty_array [CACHE_LINES];
    logic [TAG_WIDTH-1:0]       tag_array   [CACHE_LINES];
    logic [DATA_WIDTH-1:0]      data_array  [CACHE_LINES][LINE_SIZE];

    // Cache lookup signals
    logic hit;
    logic dirty;

    assign hit   = valid_array[addr_index] && (tag_array[addr_index] == addr_tag);
    assign dirty = dirty_array[addr_index];

    // FSM states
    typedef enum logic [2:0] {
        S_IDLE,
        S_COMPARE,
        S_WRITEBACK,
        S_WRITEBACK_WAIT,
        S_ALLOCATE,
        S_ALLOCATE_WAIT
    } state_t;

    state_t state, next_state;

    // Line transfer counter
    logic [OFFSET_WIDTH:0] line_counter;
    logic                  line_counter_done;

    assign line_counter_done = (line_counter == LINE_SIZE);

    // Registered CPU address for multi-cycle operations
    logic [ADDR_WIDTH-1:0]  addr_reg;
    logic [DATA_WIDTH-1:0]  wdata_reg;
    logic                   wr_reg;

    // --- State register ---
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= S_IDLE;
        else
            state <= next_state;
    end

    // --- Next-state logic ---
    always_comb begin
        next_state = state;

        unique case (state)
            S_IDLE: begin
                if (cpu_req)
                    next_state = S_COMPARE;
            end

            S_COMPARE: begin
                if (hit)
                    next_state = S_IDLE;
                else if (valid_array[addr_index] && dirty)
                    next_state = S_WRITEBACK;
                else
                    next_state = S_ALLOCATE;
            end

            S_WRITEBACK: begin
                next_state = S_WRITEBACK_WAIT;
            end

            S_WRITEBACK_WAIT: begin
                if (mem_ready && line_counter_done)
                    next_state = S_ALLOCATE;
                else if (mem_ready)
                    next_state = S_WRITEBACK;
            end

            S_ALLOCATE: begin
                next_state = S_ALLOCATE_WAIT;
            end

            S_ALLOCATE_WAIT: begin
                if (mem_ready && line_counter_done)
                    next_state = S_COMPARE;
                else if (mem_ready)
                    next_state = S_ALLOCATE;
            end

            default: next_state = S_IDLE;
        endcase
    end

    // --- Datapath ---
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < CACHE_LINES; i++) begin
                valid_array[i] <= 1'b0;
                dirty_array[i] <= 1'b0;
                tag_array[i]   <= '0;
            end
            cpu_ready    <= 1'b0;
            cpu_rdata    <= '0;
            mem_req      <= 1'b0;
            mem_wr       <= 1'b0;
            mem_addr     <= '0;
            mem_wdata    <= '0;
            line_counter <= '0;
            addr_reg     <= '0;
            wdata_reg    <= '0;
            wr_reg       <= 1'b0;
        end else begin
            cpu_ready <= 1'b0;
            mem_req   <= 1'b0;

            unique case (state)
                S_IDLE: begin
                    if (cpu_req) begin
                        addr_reg  <= cpu_addr;
                        wdata_reg <= cpu_wdata;
                        wr_reg    <= cpu_wr;
                    end
                    line_counter <= '0;
                end

                S_COMPARE: begin
                    if (hit) begin
                        if (wr_reg) begin
                            data_array[addr_index][addr_offset] <= wdata_reg;
                            dirty_array[addr_index] <= 1'b1;
                        end else begin
                            cpu_rdata <= data_array[addr_index][addr_offset];
                        end
                        cpu_ready <= 1'b1;
                    end
                    line_counter <= '0;
                end

                S_WRITEBACK: begin
                    mem_req   <= 1'b1;
                    mem_wr    <= 1'b1;
                    mem_addr  <= {tag_array[addr_index], addr_index,
                                  line_counter[OFFSET_WIDTH-1:0], 2'b00};
                    mem_wdata <= data_array[addr_index][line_counter[OFFSET_WIDTH-1:0]];
                end

                S_WRITEBACK_WAIT: begin
                    if (mem_ready) begin
                        line_counter <= line_counter + 1;
                        if (line_counter_done) begin
                            dirty_array[addr_index] <= 1'b0;
                            line_counter <= '0;
                        end
                    end
                end

                S_ALLOCATE: begin
                    mem_req  <= 1'b1;
                    mem_wr   <= 1'b0;
                    mem_addr <= {addr_tag, addr_index,
                                 line_counter[OFFSET_WIDTH-1:0], 2'b00};
                end

                S_ALLOCATE_WAIT: begin
                    if (mem_ready) begin
                        data_array[addr_index][line_counter[OFFSET_WIDTH-1:0]] <= mem_rdata;
                        line_counter <= line_counter + 1;
                        if (line_counter_done) begin
                            valid_array[addr_index] <= 1'b1;
                            tag_array[addr_index]   <= addr_tag;
                            dirty_array[addr_index] <= 1'b0;
                            line_counter <= '0;
                        end
                    end
                end

                default: ;
            endcase
        end
    end

endmodule
