// SystemVerilog Package
// Packages group related types, constants, and functions for reuse
// across multiple modules. They provide namespace isolation.

package common_pkg;

    // --- Type definitions ---
    typedef enum logic [2:0] {
        OP_NOP  = 3'b000,
        OP_READ = 3'b001,
        OP_WRITE= 3'b010,
        OP_RMW  = 3'b011,   // Read-Modify-Write
        OP_BURST= 3'b100
    } opcode_e;

    typedef enum logic [1:0] {
        RESP_OKAY   = 2'b00,
        RESP_EXOKAY = 2'b01,
        RESP_SLVERR = 2'b10,
        RESP_DECERR = 2'b11
    } resp_e;

    typedef struct packed {
        logic [31:0] address;
        logic [31:0] data;
        opcode_e     opcode;
        logic [3:0]  byte_en;
        logic [7:0]  burst_len;
        logic        last;
    } transaction_t;

    // --- Constants ---
    localparam int AXI_ADDR_WIDTH = 32;
    localparam int AXI_DATA_WIDTH = 32;
    localparam int AXI_STRB_WIDTH = AXI_DATA_WIDTH / 8;

    // --- Functions ---
    function automatic logic [31:0] byte_reverse(input logic [31:0] data);
        return {data[7:0], data[15:8], data[23:16], data[31:24]};
    endfunction

    function automatic int clog2_func(input int value);
        int result;
        result = 0;
        value = value - 1;
        while (value > 0) begin
            result++;
            value = value >> 1;
        end
        return result;
    endfunction

    function automatic logic [31:0] align_address(
        input logic [31:0] addr,
        input int          alignment
    );
        logic [31:0] mask;
        mask = alignment - 1;
        return addr & ~mask;
    endfunction

    // Parity calculation
    function automatic logic calc_parity(input logic [7:0] data);
        return ^data;
    endfunction

endpackage


// Module using the package
module transaction_processor
    import common_pkg::*;
(
    input  logic          clk,
    input  logic          rst_n,
    input  transaction_t  txn_in,
    input  logic          txn_valid,
    output transaction_t  txn_out,
    output logic          txn_done,
    output resp_e         response
);

    transaction_t txn_reg;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            txn_reg  <= '0;
            txn_done <= 1'b0;
            response <= RESP_OKAY;
        end else if (txn_valid) begin
            txn_reg  <= txn_in;
            txn_done <= 1'b1;

            unique case (txn_in.opcode)
                OP_READ:  response <= RESP_OKAY;
                OP_WRITE: response <= RESP_OKAY;
                OP_RMW:   response <= RESP_OKAY;
                OP_BURST: response <= RESP_OKAY;
                default:  response <= RESP_SLVERR;
            endcase
        end else begin
            txn_done <= 1'b0;
        end
    end

    always_comb begin
        txn_out = txn_reg;
        if (txn_reg.opcode == OP_READ)
            txn_out.data = byte_reverse(txn_reg.data);
    end

endmodule
