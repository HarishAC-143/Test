// Bus Subordinate Module
// A simple register bank accessible through the simple_bus_if interface.
// Demonstrates interface modport usage on the subordinate side.

module bus_subordinate #(
    parameter NUM_REGS   = 16,
    parameter ADDR_WIDTH = 16,
    parameter DATA_WIDTH = 32
)(
    input  logic clk,
    input  logic rst_n,
    simple_bus_if.subordinate bus
);

    localparam REG_ADDR_BITS = $clog2(NUM_REGS);

    logic [DATA_WIDTH-1:0] regs [0:NUM_REGS-1];
    logic [REG_ADDR_BITS-1:0] reg_addr;

    assign reg_addr = bus.addr[REG_ADDR_BITS-1:0];

    // Grant immediately when request is active
    assign bus.gnt = bus.req;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bus.valid <= 1'b0;
            bus.ready <= 1'b0;
            bus.rdata <= '0;
            for (int i = 0; i < NUM_REGS; i++)
                regs[i] <= '0;
        end else begin
            bus.valid <= 1'b0;
            bus.ready <= 1'b0;

            if (bus.req && bus.gnt) begin
                if (bus.we) begin
                    // Write transaction
                    regs[reg_addr] <= bus.wdata;
                    bus.ready      <= 1'b1;
                end else begin
                    // Read transaction
                    bus.rdata <= regs[reg_addr];
                    bus.valid <= 1'b1;
                end
            end
        end
    end

endmodule
