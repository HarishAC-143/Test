// Simple Bus Interface using SystemVerilog interface construct
// Shows how interfaces reduce port clutter and improve reusability

interface simple_bus_if #(
    parameter ADDR_WIDTH = 16,
    parameter DATA_WIDTH = 32
);
    logic                    req;
    logic                    gnt;
    logic [ADDR_WIDTH-1:0]   addr;
    logic [DATA_WIDTH-1:0]   wdata;
    logic [DATA_WIDTH-1:0]   rdata;
    logic                    we;
    logic                    valid;
    logic                    ready;

    modport master (
        output req, addr, wdata, we,
        input  gnt, rdata, valid, ready
    );

    modport slave (
        input  req, addr, wdata, we,
        output gnt, rdata, valid, ready
    );

endinterface


// Master that writes incrementing data
module bus_master (
    input  logic clk,
    input  logic rst_n,
    input  logic start,
    simple_bus_if.master bus
);

    typedef enum logic [1:0] {
        IDLE,
        REQUEST,
        TRANSFER,
        DONE
    } state_e;

    state_e state;
    logic [15:0] addr_counter;
    logic [31:0] data_counter;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state        <= IDLE;
            bus.req      <= 1'b0;
            bus.addr     <= '0;
            bus.wdata    <= '0;
            bus.we       <= 1'b0;
            addr_counter <= '0;
            data_counter <= '0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        bus.req <= 1'b1;
                        state   <= REQUEST;
                    end
                end

                REQUEST: begin
                    if (bus.gnt) begin
                        bus.addr  <= addr_counter;
                        bus.wdata <= data_counter;
                        bus.we    <= 1'b1;
                        state     <= TRANSFER;
                    end
                end

                TRANSFER: begin
                    if (bus.ready) begin
                        addr_counter <= addr_counter + 16'd4;
                        data_counter <= data_counter + 32'd1;
                        bus.req      <= 1'b0;
                        state        <= DONE;
                    end
                end

                DONE: begin
                    bus.we <= 1'b0;
                    state  <= IDLE;
                end
            endcase
        end
    end

endmodule


// Slave that accepts writes and stores in memory
module bus_slave #(
    parameter MEM_DEPTH = 256
)(
    input  logic clk,
    input  logic rst_n,
    simple_bus_if.slave bus
);

    logic [31:0] memory [0:MEM_DEPTH-1];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bus.gnt   <= 1'b0;
            bus.rdata <= '0;
            bus.valid <= 1'b0;
            bus.ready <= 1'b0;
        end else begin
            bus.gnt   <= bus.req;
            bus.ready <= 1'b0;
            bus.valid <= 1'b0;

            if (bus.gnt && bus.req) begin
                if (bus.we) begin
                    memory[bus.addr[9:2]] <= bus.wdata;
                    bus.ready <= 1'b1;
                end else begin
                    bus.rdata <= memory[bus.addr[9:2]];
                    bus.valid <= 1'b1;
                    bus.ready <= 1'b1;
                end
            end
        end
    end

endmodule
