// Packet Definitions Package
// Demonstrates SystemVerilog packages, typedefs, structs, and enums
// for building structured data paths.

package packet_structs_pkg;

    // Packet type enumeration
    typedef enum logic [1:0] {
        PKT_DATA    = 2'b00,
        PKT_CONTROL = 2'b01,
        PKT_STATUS  = 2'b10,
        PKT_ERROR   = 2'b11
    } pkt_type_t;

    // Priority levels
    typedef enum logic [1:0] {
        PRIO_LOW    = 2'b00,
        PRIO_MEDIUM = 2'b01,
        PRIO_HIGH   = 2'b10,
        PRIO_URGENT = 2'b11
    } pkt_prio_t;

    // Packet header — 16 bits total
    typedef struct packed {
        pkt_type_t        pkt_type;   // [15:14]
        pkt_prio_t        priority;   // [13:12]
        logic [3:0]       src_id;     // [11:8]
        logic [3:0]       dst_id;     // [7:4]
        logic [3:0]       length;     // [3:0]  payload words
    } pkt_header_t;

    // Full packet — header + payload
    typedef struct packed {
        pkt_header_t      header;
        logic [3:0][31:0] payload;    // up to 4 x 32-bit words
    } packet_t;

    // Helper function: create a header
    function automatic pkt_header_t make_header(
        pkt_type_t ptype,
        pkt_prio_t prio,
        logic [3:0] src,
        logic [3:0] dst,
        logic [3:0] len
    );
        pkt_header_t h;
        h.pkt_type = ptype;
        h.priority = prio;
        h.src_id   = src;
        h.dst_id   = dst;
        h.length   = len;
        return h;
    endfunction

endpackage
