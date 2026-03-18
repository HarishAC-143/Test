// =============================================================================
// Advanced FSM: AXI-Stream Packet Processor
// Demonstrates: Enum states, complex FSMs, typedef, struct, case/unique case
// =============================================================================

package pkt_types;
    typedef enum logic [2:0] {
        PKT_DATA    = 3'b000,
        PKT_HEADER  = 3'b001,
        PKT_TRAILER = 3'b010,
        PKT_CONTROL = 3'b011,
        PKT_ERROR   = 3'b100
    } pkt_type_e;

    typedef struct packed {
        logic [15:0] length;
        logic [7:0]  src_id;
        logic [7:0]  dst_id;
        pkt_type_e   pkt_type;
        logic [4:0]  reserved;
    } pkt_header_t;
endpackage

module advanced_fsm
    import pkt_types::*;
#(
    parameter int DATA_WIDTH = 32
) (
    input  logic                  clk,
    input  logic                  rst_n,

    // AXI-Stream input
    input  logic [DATA_WIDTH-1:0] s_axis_tdata,
    input  logic                  s_axis_tvalid,
    input  logic                  s_axis_tlast,
    output logic                  s_axis_tready,

    // AXI-Stream output (filtered/processed)
    output logic [DATA_WIDTH-1:0] m_axis_tdata,
    output logic                  m_axis_tvalid,
    output logic                  m_axis_tlast,
    input  logic                  m_axis_tready,

    // Status
    output logic                  pkt_error,
    output logic [31:0]           pkt_count,
    output logic [31:0]           error_count
);

    typedef enum logic [2:0] {
        ST_IDLE,
        ST_HEADER,
        ST_PAYLOAD,
        ST_TRAILER,
        ST_ERROR,
        ST_DROP
    } state_e;

    state_e state, next_state;

    pkt_header_t current_header;
    logic [15:0] byte_counter;
    logic        handshake;

    assign handshake = s_axis_tvalid && s_axis_tready;

    // State register
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= ST_IDLE;
        else
            state <= next_state;
    end

    // Next state logic
    always_comb begin
        next_state = state;
        unique case (state)
            ST_IDLE: begin
                if (s_axis_tvalid)
                    next_state = ST_HEADER;
            end

            ST_HEADER: begin
                if (handshake) begin
                    if (s_axis_tdata[2:0] == PKT_ERROR)
                        next_state = ST_DROP;
                    else if (s_axis_tdata[31:16] == '0)
                        next_state = ST_ERROR;
                    else
                        next_state = ST_PAYLOAD;
                end
            end

            ST_PAYLOAD: begin
                if (handshake) begin
                    if (byte_counter <= DATA_WIDTH/8)
                        next_state = ST_TRAILER;
                    else if (s_axis_tlast)
                        next_state = ST_ERROR;
                end
            end

            ST_TRAILER: begin
                if (handshake)
                    next_state = s_axis_tlast ? ST_IDLE : ST_ERROR;
            end

            ST_ERROR: begin
                if (s_axis_tlast && handshake)
                    next_state = ST_IDLE;
            end

            ST_DROP: begin
                if (s_axis_tlast && handshake)
                    next_state = ST_IDLE;
            end

            default: next_state = ST_IDLE;
        endcase
    end

    // Output and datapath logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_header <= '0;
            byte_counter   <= '0;
            pkt_count      <= '0;
            error_count    <= '0;
            pkt_error      <= 1'b0;
            m_axis_tdata   <= '0;
            m_axis_tvalid  <= 1'b0;
            m_axis_tlast   <= 1'b0;
            s_axis_tready  <= 1'b0;
        end else begin
            m_axis_tvalid <= 1'b0;
            m_axis_tlast  <= 1'b0;
            pkt_error     <= 1'b0;

            unique case (state)
                ST_IDLE: begin
                    s_axis_tready <= 1'b1;
                    byte_counter  <= '0;
                end

                ST_HEADER: begin
                    s_axis_tready <= 1'b1;
                    if (handshake) begin
                        current_header <= pkt_header_t'(s_axis_tdata);
                        byte_counter   <= s_axis_tdata[31:16];
                    end
                end

                ST_PAYLOAD: begin
                    s_axis_tready <= m_axis_tready;
                    if (handshake) begin
                        m_axis_tdata  <= s_axis_tdata;
                        m_axis_tvalid <= 1'b1;
                        byte_counter  <= byte_counter - DATA_WIDTH/8;
                    end
                end

                ST_TRAILER: begin
                    s_axis_tready <= m_axis_tready;
                    if (handshake) begin
                        m_axis_tdata  <= s_axis_tdata;
                        m_axis_tvalid <= 1'b1;
                        m_axis_tlast  <= 1'b1;
                        pkt_count     <= pkt_count + 1;
                    end
                end

                ST_ERROR: begin
                    s_axis_tready <= 1'b1;
                    pkt_error     <= 1'b1;
                    if (s_axis_tlast && handshake)
                        error_count <= error_count + 1;
                end

                ST_DROP: begin
                    s_axis_tready <= 1'b1;
                end

                default: ;
            endcase
        end
    end

    // Coverage for FSM transitions
    // synthesis translate_off
    covergroup fsm_cg @(posedge clk);
        cp_state: coverpoint state {
            bins idle    = {ST_IDLE};
            bins header  = {ST_HEADER};
            bins payload = {ST_PAYLOAD};
            bins trailer = {ST_TRAILER};
            bins error   = {ST_ERROR};
            bins drop    = {ST_DROP};
        }
        cp_transitions: coverpoint state {
            bins idle_to_header    = (ST_IDLE    => ST_HEADER);
            bins header_to_payload = (ST_HEADER  => ST_PAYLOAD);
            bins payload_to_trail  = (ST_PAYLOAD => ST_TRAILER);
            bins trailer_to_idle   = (ST_TRAILER => ST_IDLE);
            bins any_to_error      = (ST_HEADER  => ST_ERROR),
                                     (ST_PAYLOAD => ST_ERROR),
                                     (ST_TRAILER => ST_ERROR);
        }
    endgroup
    fsm_cg cg_inst = new();
    // synthesis translate_on

endmodule
