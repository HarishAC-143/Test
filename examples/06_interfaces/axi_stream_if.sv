// SystemVerilog Interface: AXI-Stream
// Interfaces bundle related signals and define modports for directional access.
// They reduce port list clutter and ensure consistent connectivity.

interface axi_stream_if #(
    parameter int DATA_WIDTH = 32,
    parameter int ID_WIDTH   = 4,
    parameter int USER_WIDTH = 1
) (
    input logic clk,
    input logic rst_n
);

    logic [DATA_WIDTH-1:0]   tdata;
    logic [DATA_WIDTH/8-1:0] tstrb;
    logic [DATA_WIDTH/8-1:0] tkeep;
    logic                    tvalid;
    logic                    tready;
    logic                    tlast;
    logic [ID_WIDTH-1:0]     tid;
    logic [USER_WIDTH-1:0]   tuser;

    // Master drives tdata, tvalid, etc.; reads tready
    modport master (
        input  clk, rst_n,
        output tdata, tstrb, tkeep, tvalid, tlast, tid, tuser,
        input  tready
    );

    // Slave reads data signals; drives tready
    modport slave (
        input  clk, rst_n,
        input  tdata, tstrb, tkeep, tvalid, tlast, tid, tuser,
        output tready
    );

    // Monitor can only observe
    modport monitor (
        input clk, rst_n,
        input tdata, tstrb, tkeep, tvalid, tready, tlast, tid, tuser
    );

endinterface


// Example: AXI-Stream Data Doubler using interface
// Reads input stream, multiplies data by 2, outputs on another stream
module axis_data_doubler (
    axi_stream_if.slave  s_axis,
    axi_stream_if.master m_axis
);

    assign m_axis.tdata  = s_axis.tdata << 1;
    assign m_axis.tvalid = s_axis.tvalid;
    assign m_axis.tlast  = s_axis.tlast;
    assign m_axis.tkeep  = s_axis.tkeep;
    assign m_axis.tstrb  = s_axis.tstrb;
    assign m_axis.tid    = s_axis.tid;
    assign m_axis.tuser  = s_axis.tuser;
    assign s_axis.tready = m_axis.tready;

endmodule


// Example: AXI-Stream Register Slice (pipeline stage)
// Breaks combinational paths between master and slave for timing closure
module axis_register_slice #(
    parameter int DATA_WIDTH = 32
) (
    axi_stream_if.slave  s_axis,
    axi_stream_if.master m_axis
);

    logic [DATA_WIDTH-1:0] data_reg;
    logic                  valid_reg;
    logic                  last_reg;

    wire handshake_in  = s_axis.tvalid && s_axis.tready;
    wire handshake_out = m_axis.tvalid && m_axis.tready;

    always_ff @(posedge s_axis.clk or negedge s_axis.rst_n) begin
        if (!s_axis.rst_n) begin
            data_reg  <= '0;
            valid_reg <= 1'b0;
            last_reg  <= 1'b0;
        end else begin
            if (handshake_in) begin
                data_reg  <= s_axis.tdata;
                valid_reg <= 1'b1;
                last_reg  <= s_axis.tlast;
            end else if (handshake_out) begin
                valid_reg <= 1'b0;
            end
        end
    end

    assign m_axis.tdata  = data_reg;
    assign m_axis.tvalid = valid_reg;
    assign m_axis.tlast  = last_reg;
    assign s_axis.tready = !valid_reg || m_axis.tready;

endmodule
