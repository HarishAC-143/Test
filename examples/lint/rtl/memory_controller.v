// =============================================================================
// Memory Controller — Clean Lint Example
// =============================================================================
// A simple memory controller demonstrating lint-clean RTL coding style.
// This module shows best practices for writing SpyGlass-friendly code.
// =============================================================================

module memory_controller #(
    parameter ADDR_WIDTH = 16,
    parameter DATA_WIDTH = 32,
    parameter BURST_LEN  = 4
) (
    input  wire                    clk,
    input  wire                    rst_n,

    // Host interface
    input  wire                    host_req,
    input  wire                    host_wr,
    input  wire [ADDR_WIDTH-1:0]   host_addr,
    input  wire [DATA_WIDTH-1:0]   host_wdata,
    output reg  [DATA_WIDTH-1:0]   host_rdata,
    output reg                     host_ack,
    output reg                     host_error,

    // Memory interface
    output reg                     mem_ce_n,
    output reg                     mem_we_n,
    output reg                     mem_oe_n,
    output reg  [ADDR_WIDTH-1:0]   mem_addr,
    output reg  [DATA_WIDTH-1:0]   mem_wdata,
    input  wire [DATA_WIDTH-1:0]   mem_rdata,
    input  wire                    mem_ready
);

    // State encoding using localparam
    localparam [2:0] ST_IDLE    = 3'd0,
                     ST_SETUP   = 3'd1,
                     ST_ACCESS  = 3'd2,
                     ST_WAIT    = 3'd3,
                     ST_BURST   = 3'd4,
                     ST_DONE    = 3'd5,
                     ST_ERROR   = 3'd6;

    reg [2:0] state, next_state;
    reg [$clog2(BURST_LEN)-1:0] burst_cnt;
    reg                          wr_pending;
    reg [ADDR_WIDTH-1:0]         addr_reg;
    reg [DATA_WIDTH-1:0]         wdata_reg;

    // Next-state logic (combinational, blocking assignments)
    always @(*) begin
        next_state = state;

        case (state)
            ST_IDLE: begin
                if (host_req)
                    next_state = ST_SETUP;
            end

            ST_SETUP:
                next_state = ST_ACCESS;

            ST_ACCESS: begin
                if (mem_ready)
                    next_state = ST_DONE;
                else
                    next_state = ST_WAIT;
            end

            ST_WAIT: begin
                if (mem_ready)
                    next_state = ST_DONE;
            end

            ST_BURST: begin
                if (burst_cnt == BURST_LEN[$clog2(BURST_LEN)-1:0] - 1'b1)
                    next_state = ST_DONE;
            end

            ST_DONE:
                next_state = ST_IDLE;

            ST_ERROR:
                next_state = ST_IDLE;

            default:
                next_state = ST_IDLE;
        endcase
    end

    // State register (sequential, non-blocking assignments)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= ST_IDLE;
        else
            state <= next_state;
    end

    // Datapath and output registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_ce_n    <= 1'b1;
            mem_we_n    <= 1'b1;
            mem_oe_n    <= 1'b1;
            mem_addr    <= {ADDR_WIDTH{1'b0}};
            mem_wdata   <= {DATA_WIDTH{1'b0}};
            host_rdata  <= {DATA_WIDTH{1'b0}};
            host_ack    <= 1'b0;
            host_error  <= 1'b0;
            burst_cnt   <= {$clog2(BURST_LEN){1'b0}};
            wr_pending  <= 1'b0;
            addr_reg    <= {ADDR_WIDTH{1'b0}};
            wdata_reg   <= {DATA_WIDTH{1'b0}};
        end else begin
            host_ack   <= 1'b0;
            host_error <= 1'b0;

            case (state)
                ST_IDLE: begin
                    mem_ce_n <= 1'b1;
                    mem_we_n <= 1'b1;
                    mem_oe_n <= 1'b1;
                    if (host_req) begin
                        addr_reg   <= host_addr;
                        wdata_reg  <= host_wdata;
                        wr_pending <= host_wr;
                    end
                end

                ST_SETUP: begin
                    mem_ce_n  <= 1'b0;
                    mem_addr  <= addr_reg;
                    mem_wdata <= wdata_reg;
                    mem_we_n  <= ~wr_pending;
                    mem_oe_n  <= wr_pending;
                end

                ST_ACCESS: begin
                    if (mem_ready && !wr_pending)
                        host_rdata <= mem_rdata;
                end

                ST_WAIT: begin
                    if (mem_ready && !wr_pending)
                        host_rdata <= mem_rdata;
                end

                ST_BURST: begin
                    burst_cnt <= burst_cnt + 1'b1;
                    mem_addr  <= addr_reg + {{(ADDR_WIDTH-$clog2(BURST_LEN)){1'b0}}, burst_cnt};
                end

                ST_DONE: begin
                    mem_ce_n   <= 1'b1;
                    mem_we_n   <= 1'b1;
                    mem_oe_n   <= 1'b1;
                    host_ack   <= 1'b1;
                    wr_pending <= 1'b0;
                end

                ST_ERROR: begin
                    mem_ce_n   <= 1'b1;
                    mem_we_n   <= 1'b1;
                    mem_oe_n   <= 1'b1;
                    host_error <= 1'b1;
                end

                default: begin
                    mem_ce_n <= 1'b1;
                    mem_we_n <= 1'b1;
                    mem_oe_n <= 1'b1;
                end
            endcase
        end
    end

endmodule
