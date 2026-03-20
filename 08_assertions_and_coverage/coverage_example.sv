// Functional coverage example for a bus protocol.
// Demonstrates covergroups, coverpoints, bins, and cross coverage.

module coverage_example (
    input  logic        clk,
    input  logic        rst_n,
    input  logic [1:0]  txn_type,    // 00=idle, 01=read, 10=write, 11=reserved
    input  logic [15:0] addr,
    input  logic [31:0] data,
    input  logic        valid,
    input  logic        error
);

    // =========================================================================
    // Transaction type coverage
    // =========================================================================
    covergroup cg_transaction @(posedge clk iff (valid && rst_n));

        cp_type: coverpoint txn_type {
            bins idle     = {2'b00};
            bins read     = {2'b01};
            bins write    = {2'b10};
            bins reserved = {2'b11};
            illegal_bins bad = {2'b11};   // should never occur
        }

        cp_addr_range: coverpoint addr {
            bins low      = {[16'h0000:16'h00FF]};
            bins mid      = {[16'h0100:16'h0FFF]};
            bins high     = {[16'h1000:16'hFFFF]};
        }

        cp_data_pattern: coverpoint data {
            bins zero     = {32'h0};
            bins all_ones = {32'hFFFF_FFFF};
            bins others   = default;
        }

        cp_error: coverpoint error {
            bins no_error = {1'b0};
            bins error    = {1'b1};
        }

        // Cross coverage: which transaction types hit which address ranges?
        cross_type_addr: cross cp_type, cp_addr_range;

        // Cross coverage: errors per transaction type
        cross_type_error: cross cp_type, cp_error;

    endgroup

    cg_transaction cg_txn_inst = new();

    // =========================================================================
    // Transition coverage: track state transitions
    // =========================================================================
    covergroup cg_transitions @(posedge clk iff (valid && rst_n));

        cp_type_transitions: coverpoint txn_type {
            bins idle_to_read   = (2'b00 => 2'b01);
            bins idle_to_write  = (2'b00 => 2'b10);
            bins read_to_write  = (2'b01 => 2'b10);
            bins write_to_read  = (2'b10 => 2'b01);
            bins read_to_idle   = (2'b01 => 2'b00);
            bins write_to_idle  = (2'b10 => 2'b00);
        }

    endgroup

    cg_transitions cg_trans_inst = new();

endmodule
