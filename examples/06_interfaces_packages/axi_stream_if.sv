// ============================================================================
// AXI-Stream Interface
// ============================================================================
// Interfaces bundle related signals and define modports for different
// perspectives (master vs. slave). This eliminates port-list boilerplate
// and ensures consistent signal naming across the design.
//
// Usage:
//   axi_stream_if #(.DATA_WIDTH(32)) axis (.clk(clk), .rst_n(rst_n));
//
//   my_source u_src (.m_axis(axis.master));
//   my_sink   u_snk (.s_axis(axis.slave));
// ============================================================================

interface axi_stream_if #(
    parameter int DATA_WIDTH = 32,
    parameter int ID_WIDTH   = 4,
    parameter int USER_WIDTH = 1
)(
    input logic clk,
    input logic rst_n
);

    logic [DATA_WIDTH-1:0]   tdata;
    logic [DATA_WIDTH/8-1:0] tkeep;
    logic [DATA_WIDTH/8-1:0] tstrb;
    logic [ID_WIDTH-1:0]     tid;
    logic [USER_WIDTH-1:0]   tuser;
    logic                    tvalid;
    logic                    tready;
    logic                    tlast;

    // Master drives data, slave accepts
    modport master (
        input  clk, rst_n,
        output tdata, tkeep, tstrb, tid, tuser, tvalid, tlast,
        input  tready
    );

    // Slave accepts data, drives ready
    modport slave (
        input  clk, rst_n,
        input  tdata, tkeep, tstrb, tid, tuser, tvalid, tlast,
        output tready
    );

    // Monitor port for verification — all signals are inputs
    modport monitor (
        input clk, rst_n,
        input tdata, tkeep, tstrb, tid, tuser, tvalid, tready, tlast
    );

`ifndef SYNTHESIS
    // Protocol assertions (simulation only)
    property valid_stable_until_ready;
        @(posedge clk) disable iff (!rst_n)
        tvalid && !tready |=> tvalid;
    endproperty

    property data_stable_until_ready;
        @(posedge clk) disable iff (!rst_n)
        tvalid && !tready |=> $stable(tdata);
    endproperty

    assert property (valid_stable_until_ready)
        else $error("AXI-S: tvalid dropped before tready");

    assert property (data_stable_until_ready)
        else $error("AXI-S: tdata changed while tvalid && !tready");
`endif

endinterface


// ============================================================================
// Example: AXI-Stream Pass-Through with Register Slice
// ============================================================================
// Inserts a pipeline register on an AXI-Stream bus for timing closure.
// ============================================================================

module axis_register_slice #(
    parameter int DATA_WIDTH = 32
)(
    axi_stream_if.slave  s_axis,
    axi_stream_if.master m_axis
);

    logic [DATA_WIDTH-1:0] data_reg;
    logic                  last_reg;
    logic                  valid_reg;

    assign s_axis.tready = !valid_reg || m_axis.tready;

    always_ff @(posedge s_axis.clk or negedge s_axis.rst_n) begin
        if (!s_axis.rst_n) begin
            valid_reg <= 1'b0;
            data_reg  <= '0;
            last_reg  <= 1'b0;
        end else begin
            if (s_axis.tready) begin
                valid_reg <= s_axis.tvalid;
                data_reg  <= s_axis.tdata;
                last_reg  <= s_axis.tlast;
            end
        end
    end

    assign m_axis.tdata  = data_reg;
    assign m_axis.tlast  = last_reg;
    assign m_axis.tvalid = valid_reg;
    assign m_axis.tkeep  = '1;
    assign m_axis.tstrb  = '1;
    assign m_axis.tid    = '0;
    assign m_axis.tuser  = '0;

endmodule
