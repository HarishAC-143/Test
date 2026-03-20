// Bus Master Module
// Issues read and write transactions through the simple_bus_if interface.
// Demonstrates interface modport usage on the master side.

module bus_master (
    input  logic clk,
    input  logic rst_n,
    // Control inputs
    input  logic             start_wr,
    input  logic             start_rd,
    input  logic [15:0]      target_addr,
    input  logic [31:0]      wr_data,
    output logic [31:0]      rd_data,
    output logic             done,
    // Bus interface
    simple_bus_if.master     bus
);

    typedef enum logic [2:0] {
        IDLE,
        REQ,
        WAIT_GNT,
        WRITE,
        READ,
        COMPLETE
    } state_t;

    state_t state, next_state;
    logic save_read;

    // State register
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= IDLE;
        else
            state <= next_state;
    end

    // Capture read data
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            rd_data <= '0;
        else if (save_read)
            rd_data <= bus.rdata;
    end

    // Next-state and output logic
    always_comb begin
        next_state = state;
        bus.req    = 1'b0;
        bus.we     = 1'b0;
        bus.addr   = '0;
        bus.wdata  = '0;
        done       = 1'b0;
        save_read  = 1'b0;

        case (state)
            IDLE: begin
                if (start_wr || start_rd)
                    next_state = REQ;
            end

            REQ: begin
                bus.req  = 1'b1;
                bus.addr = target_addr;
                if (bus.gnt)
                    next_state = start_wr ? WRITE : READ;
                else
                    next_state = WAIT_GNT;
            end

            WAIT_GNT: begin
                bus.req  = 1'b1;
                bus.addr = target_addr;
                if (bus.gnt)
                    next_state = start_wr ? WRITE : READ;
            end

            WRITE: begin
                bus.req   = 1'b1;
                bus.we    = 1'b1;
                bus.addr  = target_addr;
                bus.wdata = wr_data;
                if (bus.ready)
                    next_state = COMPLETE;
            end

            READ: begin
                bus.req  = 1'b1;
                bus.addr = target_addr;
                if (bus.valid) begin
                    save_read  = 1'b1;
                    next_state = COMPLETE;
                end
            end

            COMPLETE: begin
                done       = 1'b1;
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

endmodule
