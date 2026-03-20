// Top-level module demonstrating interface instantiation and connection.

module top_with_interface (
    input  logic clk,
    input  logic rst_n
);

    // Instantiate the interface
    simple_bus_if #(
        .ADDR_WIDTH (16),
        .DATA_WIDTH (32)
    ) bus ();

    // Connect master
    bus_master u_master (
        .clk       (clk),
        .rst_n     (rst_n),
        .start     (1'b0),
        .wr        (1'b0),
        .addr      (16'h0),
        .wdata     (32'h0),
        .busy      (),
        .rdata_out (),
        .done      (),
        .bus       (bus.master)
    );

    // Connect slave
    bus_slave #(
        .NUM_REGS (8)
    ) u_slave (
        .clk   (clk),
        .rst_n (rst_n),
        .bus   (bus.slave)
    );

endmodule
