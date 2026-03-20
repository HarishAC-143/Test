// Simple bus master — generates write and read transactions.
// Demonstrates using an interface with modport.

module bus_master (
    input  logic clk,
    input  logic rst_n,
    input  logic start,            // trigger a transaction
    input  logic wr,               // 1=write, 0=read
    input  logic [15:0] addr,
    input  logic [31:0] wdata,
    output logic busy,
    output logic [31:0] rdata_out,
    output logic done,

    simple_bus_if.master bus       // interface port with master modport
);

    typedef enum logic [1:0] {
        M_IDLE,
        M_REQ,
        M_WAIT
    } mstate_t;

    mstate_t state_q, state_d;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state_q <= M_IDLE;
        else
            state_q <= state_d;
    end

    always_comb begin
        state_d   = state_q;
        bus.req   = 1'b0;
        bus.wr    = 1'b0;
        bus.addr  = '0;
        bus.wdata = '0;
        busy      = 1'b0;
        done      = 1'b0;

        unique case (state_q)
            M_IDLE: begin
                if (start)
                    state_d = M_REQ;
            end

            M_REQ: begin
                bus.req   = 1'b1;
                bus.wr    = wr;
                bus.addr  = addr;
                bus.wdata = wdata;
                busy      = 1'b1;
                state_d   = M_WAIT;
            end

            M_WAIT: begin
                bus.req   = 1'b1;
                bus.wr    = wr;
                bus.addr  = addr;
                bus.wdata = wdata;
                busy      = 1'b1;

                if (bus.ack) begin
                    done    = 1'b1;
                    state_d = M_IDLE;
                end
            end

            default: state_d = M_IDLE;
        endcase
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            rdata_out <= '0;
        else if (bus.ack && !wr)
            rdata_out <= bus.rdata;
    end

endmodule
