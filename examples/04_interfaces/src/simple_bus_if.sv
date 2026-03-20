// Simple Bus Interface
// Bundles address, data, and control signals for a single-master bus.
// Modports enforce signal direction at the port boundary.

interface simple_bus_if #(
    parameter ADDR_WIDTH = 16,
    parameter DATA_WIDTH = 32
);

    logic                    req;
    logic                    gnt;
    logic                    we;
    logic [ADDR_WIDTH-1:0]   addr;
    logic [DATA_WIDTH-1:0]   wdata;
    logic [DATA_WIDTH-1:0]   rdata;
    logic                    valid;
    logic                    ready;

    // Master drives requests, subordinate responds
    modport master (
        output req, we, addr, wdata,
        input  gnt, rdata, valid, ready
    );

    modport subordinate (
        input  req, we, addr, wdata,
        output gnt, rdata, valid, ready
    );

    // Monitor port for verification
    modport monitor (
        input req, gnt, we, addr, wdata, rdata, valid, ready
    );

endinterface
