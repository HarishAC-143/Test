// =============================================================================
// APB (Advanced Peripheral Bus) Master Controller
// Implements the AMBA APB protocol for low-bandwidth peripheral access.
// Generates proper SETUP and ACCESS phases per APB specification.
// =============================================================================

module apb_master #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
) (
    input  logic                    pclk,
    input  logic                    presetn,

    // Command interface (from system controller)
    input  logic                    cmd_valid,
    input  logic                    cmd_write,  // 1 = write, 0 = read
    input  logic [ADDR_WIDTH-1:0]   cmd_addr,
    input  logic [DATA_WIDTH-1:0]   cmd_wdata,
    output logic [DATA_WIDTH-1:0]   cmd_rdata,
    output logic                    cmd_ready,
    output logic                    cmd_error,

    // APB interface
    output logic [ADDR_WIDTH-1:0]   paddr,
    output logic                    psel,
    output logic                    penable,
    output logic                    pwrite,
    output logic [DATA_WIDTH-1:0]   pwdata,
    input  logic [DATA_WIDTH-1:0]   prdata,
    input  logic                    pready,
    input  logic                    pslverr
);

    typedef enum logic [1:0] {
        ST_IDLE   = 2'b00,
        ST_SETUP  = 2'b01,
        ST_ACCESS = 2'b10
    } state_e;

    state_e state, next_state;

    always_ff @(posedge pclk or negedge presetn) begin
        if (!presetn)
            state <= ST_IDLE;
        else
            state <= next_state;
    end

    always_comb begin
        next_state = state;

        case (state)
            ST_IDLE:   if (cmd_valid) next_state = ST_SETUP;
            ST_SETUP:  next_state = ST_ACCESS;
            ST_ACCESS: begin
                if (pready)
                    next_state = cmd_valid ? ST_SETUP : ST_IDLE;
            end
            default: next_state = ST_IDLE;
        endcase
    end

    // APB signal generation
    always_ff @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            paddr   <= '0;
            psel    <= 1'b0;
            penable <= 1'b0;
            pwrite  <= 1'b0;
            pwdata  <= '0;
        end else begin
            case (next_state)
                ST_IDLE: begin
                    psel    <= 1'b0;
                    penable <= 1'b0;
                end

                ST_SETUP: begin
                    paddr   <= cmd_addr;
                    pwrite  <= cmd_write;
                    pwdata  <= cmd_wdata;
                    psel    <= 1'b1;
                    penable <= 1'b0;
                end

                ST_ACCESS: begin
                    penable <= 1'b1;
                end

                default: begin
                    psel    <= 1'b0;
                    penable <= 1'b0;
                end
            endcase
        end
    end

    assign cmd_rdata = prdata;
    assign cmd_ready = (state == ST_ACCESS) && pready;
    assign cmd_error = (state == ST_ACCESS) && pready && pslverr;

endmodule
