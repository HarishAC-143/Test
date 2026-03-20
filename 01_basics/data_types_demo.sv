// Demonstration of SystemVerilog data types for RTL and testbench use.

module data_types_demo;

    // -------------------------------------------------------------------------
    // 4-state types (synthesizable)
    // -------------------------------------------------------------------------
    logic              single_bit;
    logic [7:0]        byte_vec;
    logic [31:0]       word_vec;
    logic signed [7:0] signed_byte;    // signed arithmetic

    // -------------------------------------------------------------------------
    // Packed multi-dimensional (treated as a single vector)
    // -------------------------------------------------------------------------
    logic [3:0][7:0]   packed_word;    // 32-bit vector, accessible as packed_word[2] => byte

    // -------------------------------------------------------------------------
    // Unpacked arrays (memory-like)
    // -------------------------------------------------------------------------
    logic [7:0] mem_array [0:15];      // 16-entry memory

    // -------------------------------------------------------------------------
    // 2-state types (for testbench / high-speed simulation)
    // -------------------------------------------------------------------------
    bit                b_single;
    bit [7:0]          b_byte;
    int                b_int;          // 32-bit signed, 2-state
    byte               b_byte_type;   // 8-bit signed, 2-state
    shortint           b_short;       // 16-bit signed
    longint            b_long;        // 64-bit signed

    // -------------------------------------------------------------------------
    // Enumerated types (ideal for FSM states)
    // -------------------------------------------------------------------------
    typedef enum logic [1:0] {
        STATE_IDLE  = 2'b00,
        STATE_RUN   = 2'b01,
        STATE_DONE  = 2'b10,
        STATE_ERROR = 2'b11
    } state_t;

    state_t current_state;

    // -------------------------------------------------------------------------
    // Struct — grouping related signals
    // -------------------------------------------------------------------------
    typedef struct packed {
        logic [7:0]  addr;
        logic [31:0] data;
        logic        valid;
        logic        ready;
    } bus_pkt_t;

    bus_pkt_t packet;

    // -------------------------------------------------------------------------
    // Union — overlapping storage
    // -------------------------------------------------------------------------
    typedef union packed {
        logic [31:0]      word;
        logic [3:0][7:0]  bytes;
        logic [1:0][15:0] halves;
    } word_union_t;

    word_union_t my_word;

    // -------------------------------------------------------------------------
    // Demonstration in an initial block (testbench context)
    // -------------------------------------------------------------------------
    initial begin
        // Scalar
        single_bit  = 1'b1;

        // Vectors
        byte_vec    = 8'hA5;
        word_vec    = 32'hDEAD_BEEF;    // underscores improve readability
        signed_byte = -8'sd42;

        // Packed multi-dimensional
        packed_word = 32'h0102_0304;
        $display("packed_word[0] = 0x%02h", packed_word[0]); // 0x04
        $display("packed_word[3] = 0x%02h", packed_word[3]); // 0x01

        // Unpacked memory
        for (int i = 0; i < 16; i++)
            mem_array[i] = 8'(i * 3);

        // Enum
        current_state = STATE_IDLE;
        $display("State: %s (%0b)", current_state.name(), current_state);

        // Struct
        packet.addr  = 8'hFF;
        packet.data  = 32'h1234_5678;
        packet.valid = 1'b1;
        packet.ready = 1'b0;
        $display("Packet addr=0x%02h data=0x%08h valid=%0b",
                 packet.addr, packet.data, packet.valid);

        // Union
        my_word.word = 32'hAABB_CCDD;
        $display("word=0x%08h byte[0]=0x%02h half[1]=0x%04h",
                 my_word.word, my_word.bytes[0], my_word.halves[1]);

        $display("\n--- All data type demonstrations passed ---");
        $finish;
    end

endmodule
