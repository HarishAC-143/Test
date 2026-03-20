// Shared package — types, constants, and utility functions used across modules.

package common_pkg;

    // Global parameters
    parameter int DATA_WIDTH = 32;
    parameter int ADDR_WIDTH = 16;
    parameter int NUM_REGS   = 8;

    // Address type
    typedef logic [ADDR_WIDTH-1:0] addr_t;
    typedef logic [DATA_WIDTH-1:0] data_t;

    // Transaction type
    typedef enum logic [1:0] {
        TXN_READ  = 2'b00,
        TXN_WRITE = 2'b01,
        TXN_IDLE  = 2'b10
    } txn_type_t;

    // Bus request structure
    typedef struct packed {
        txn_type_t  txn_type;
        addr_t      addr;
        data_t      data;
        logic       valid;
    } bus_req_t;

    // Bus response structure
    typedef struct packed {
        data_t      data;
        logic       valid;
        logic       error;
    } bus_resp_t;

    // Utility function: compute parity
    function automatic logic parity(input logic [DATA_WIDTH-1:0] val);
        return ^val;
    endfunction

    // Utility function: byte-reverse a word
    function automatic data_t byte_reverse(input data_t val);
        data_t result;
        for (int i = 0; i < DATA_WIDTH/8; i++)
            result[i*8 +: 8] = val[(DATA_WIDTH/8 - 1 - i)*8 +: 8];
        return result;
    endfunction

    // Utility function: count leading zeros
    function automatic int clz(input data_t val);
        for (int i = DATA_WIDTH - 1; i >= 0; i--) begin
            if (val[i]) return DATA_WIDTH - 1 - i;
        end
        return DATA_WIDTH;
    endfunction

endpackage
