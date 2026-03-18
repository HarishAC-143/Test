// ----------------------------------------------------------------------------
// SRAM Controller with Read/Write Burst Support
// Demonstrates: memory-mapped I/O, burst transfers, wait-state insertion,
//               bank interleaving, parameterized timing
// ----------------------------------------------------------------------------

module sram_controller #(
    parameter int ADDR_WIDTH    = 20,
    parameter int DATA_WIDTH    = 32,
    parameter int NUM_BANKS     = 4,
    parameter int BURST_LEN     = 4,
    parameter int READ_LATENCY  = 2,
    parameter int WRITE_LATENCY = 1
)(
    input  logic                    clk,
    input  logic                    rst_n,

    // CPU-side interface
    input  logic [ADDR_WIDTH-1:0]   cpu_addr,
    input  logic [DATA_WIDTH-1:0]   cpu_wr_data,
    input  logic                    cpu_rd_req,
    input  logic                    cpu_wr_req,
    input  logic                    cpu_burst,
    output logic [DATA_WIDTH-1:0]   cpu_rd_data,
    output logic                    cpu_ready,
    output logic                    cpu_valid,

    // SRAM-side interface (directly drives external SRAM pins)
    output logic [ADDR_WIDTH-1:0]   sram_addr,
    inout  wire  [DATA_WIDTH-1:0]   sram_data,
    output logic                    sram_ce_n,  // Chip enable
    output logic                    sram_oe_n,  // Output enable
    output logic                    sram_we_n,  // Write enable
    output logic [DATA_WIDTH/8-1:0] sram_be_n   // Byte enables
);

    localparam int BANK_SEL_W = $clog2(NUM_BANKS);
    localparam int BURST_CNT_W = $clog2(BURST_LEN + 1);

    typedef enum logic [3:0] {
        ST_IDLE,
        ST_READ_SETUP,
        ST_READ_ACCESS,
        ST_READ_BURST,
        ST_WRITE_SETUP,
        ST_WRITE_ACCESS,
        ST_WRITE_BURST,
        ST_DONE
    } ctrl_state_t;

    ctrl_state_t state, next_state;

    logic [ADDR_WIDTH-1:0]   addr_reg;
    logic [DATA_WIDTH-1:0]   wr_data_reg;
    logic [$clog2(READ_LATENCY+1)-1:0] wait_cnt;
    logic [BURST_CNT_W-1:0]  burst_cnt;
    logic                     is_read;
    logic                     is_burst;
    logic [DATA_WIDTH-1:0]    sram_data_out;
    logic                     sram_data_oe;

    // Tri-state data bus control
    assign sram_data = sram_data_oe ? sram_data_out : {DATA_WIDTH{1'bz}};

    // Bank select from upper address bits
    wire [BANK_SEL_W-1:0] bank_sel = addr_reg[ADDR_WIDTH-1 -: BANK_SEL_W];

    // FSM state register
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= ST_IDLE;
        else
            state <= next_state;
    end

    // FSM next-state and output logic
    always_comb begin
        next_state  = state;
        cpu_ready   = 1'b0;
        cpu_valid   = 1'b0;
        sram_ce_n   = 1'b1;
        sram_oe_n   = 1'b1;
        sram_we_n   = 1'b1;
        sram_be_n   = '0;
        sram_addr   = addr_reg;
        sram_data_out = wr_data_reg;
        sram_data_oe  = 1'b0;
        cpu_rd_data   = sram_data;

        case (state)
            ST_IDLE: begin
                cpu_ready = 1'b1;
                if (cpu_rd_req)
                    next_state = ST_READ_SETUP;
                else if (cpu_wr_req)
                    next_state = ST_WRITE_SETUP;
            end

            ST_READ_SETUP: begin
                sram_ce_n = 1'b0;
                sram_oe_n = 1'b0;
                if (wait_cnt >= READ_LATENCY - 1)
                    next_state = ST_READ_ACCESS;
            end

            ST_READ_ACCESS: begin
                sram_ce_n   = 1'b0;
                sram_oe_n   = 1'b0;
                cpu_valid   = 1'b1;
                cpu_rd_data = sram_data;
                if (is_burst && burst_cnt < BURST_LEN - 1)
                    next_state = ST_READ_BURST;
                else
                    next_state = ST_DONE;
            end

            ST_READ_BURST: begin
                sram_ce_n   = 1'b0;
                sram_oe_n   = 1'b0;
                sram_addr   = addr_reg + {{(ADDR_WIDTH-BURST_CNT_W){1'b0}}, burst_cnt};
                cpu_valid   = 1'b1;
                cpu_rd_data = sram_data;
                if (burst_cnt >= BURST_LEN - 1)
                    next_state = ST_DONE;
            end

            ST_WRITE_SETUP: begin
                sram_ce_n    = 1'b0;
                sram_we_n    = 1'b0;
                sram_data_oe = 1'b1;
                if (wait_cnt >= WRITE_LATENCY - 1)
                    next_state = ST_WRITE_ACCESS;
            end

            ST_WRITE_ACCESS: begin
                sram_ce_n    = 1'b0;
                sram_we_n    = 1'b0;
                sram_data_oe = 1'b1;
                if (is_burst && burst_cnt < BURST_LEN - 1)
                    next_state = ST_WRITE_BURST;
                else
                    next_state = ST_DONE;
            end

            ST_WRITE_BURST: begin
                sram_ce_n    = 1'b0;
                sram_we_n    = 1'b0;
                sram_data_oe = 1'b1;
                sram_addr    = addr_reg + {{(ADDR_WIDTH-BURST_CNT_W){1'b0}}, burst_cnt};
                if (burst_cnt >= BURST_LEN - 1)
                    next_state = ST_DONE;
            end

            ST_DONE: begin
                next_state = ST_IDLE;
            end

            default: next_state = ST_IDLE;
        endcase
    end

    // Datapath registers
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            addr_reg    <= '0;
            wr_data_reg <= '0;
            wait_cnt    <= '0;
            burst_cnt   <= '0;
            is_read     <= 1'b0;
            is_burst    <= 1'b0;
        end else begin
            case (state)
                ST_IDLE: begin
                    wait_cnt  <= '0;
                    burst_cnt <= '0;
                    if (cpu_rd_req || cpu_wr_req) begin
                        addr_reg    <= cpu_addr;
                        wr_data_reg <= cpu_wr_data;
                        is_read     <= cpu_rd_req;
                        is_burst    <= cpu_burst;
                    end
                end

                ST_READ_SETUP, ST_WRITE_SETUP: begin
                    wait_cnt <= wait_cnt + 1'b1;
                end

                ST_READ_BURST, ST_WRITE_BURST: begin
                    burst_cnt <= burst_cnt + 1'b1;
                end

                default: ;
            endcase
        end
    end

endmodule
