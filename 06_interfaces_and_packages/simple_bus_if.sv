// Simple bus interface with modports for master and slave.

interface simple_bus_if #(
    parameter int ADDR_WIDTH = 16,
    parameter int DATA_WIDTH = 32
);

    logic                  req;       // request strobe
    logic                  wr;        // 1 = write, 0 = read
    logic [ADDR_WIDTH-1:0] addr;
    logic [DATA_WIDTH-1:0] wdata;     // write data
    logic [DATA_WIDTH-1:0] rdata;     // read data
    logic                  ack;       // transfer acknowledge
    logic                  err;       // error response

    // Master drives req, wr, addr, wdata; receives rdata, ack, err
    modport master (
        output req, wr, addr, wdata,
        input  rdata, ack, err
    );

    // Slave receives req, wr, addr, wdata; drives rdata, ack, err
    modport slave (
        input  req, wr, addr, wdata,
        output rdata, ack, err
    );

    // Monitor can only observe (for verification)
    modport monitor (
        input req, wr, addr, wdata, rdata, ack, err
    );

endinterface
