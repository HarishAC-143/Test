// Simple bus slave — register bank accessible via the bus interface.

module bus_slave #(
    parameter int NUM_REGS = 8
)(
    input  logic clk,
    input  logic rst_n,

    simple_bus_if.slave bus       // interface port with slave modport
);

    localparam int REG_ADDR_BITS = $clog2(NUM_REGS);

    logic [31:0] registers [0:NUM_REGS-1];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bus.ack   <= 1'b0;
            bus.err   <= 1'b0;
            bus.rdata <= '0;
            for (int i = 0; i < NUM_REGS; i++)
                registers[i] <= '0;
        end else if (bus.req) begin
            if (bus.addr[REG_ADDR_BITS-1:0] < NUM_REGS[REG_ADDR_BITS-1:0]) begin
                bus.ack <= 1'b1;
                bus.err <= 1'b0;
                if (bus.wr)
                    registers[bus.addr[REG_ADDR_BITS-1:0]] <= bus.wdata;
                else
                    bus.rdata <= registers[bus.addr[REG_ADDR_BITS-1:0]];
            end else begin
                bus.ack <= 1'b1;
                bus.err <= 1'b1;    // address out of range
            end
        end else begin
            bus.ack <= 1'b0;
            bus.err <= 1'b0;
        end
    end

endmodule
