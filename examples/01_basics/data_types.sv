// SystemVerilog Data Types Demonstration
// Shows logic, bit, integer, enum, struct, and array types

module data_types_demo (
    input  logic        clk,
    input  logic        rst_n,
    output logic [31:0] result
);

    // --- Two-state vs Four-state types ---
    logic [7:0]  four_state_var;   // 4-state: 0, 1, x, z (use for RTL)
    bit   [7:0]  two_state_var;    // 2-state: 0, 1 only (use for TB)

    // --- Integer types ---
    int           signed_32;       // 2-state, 32-bit signed
    integer       four_state_int;  // 4-state, 32-bit signed
    shortint      signed_16;       // 2-state, 16-bit signed
    longint       signed_64;       // 2-state, 64-bit signed
    byte          signed_8;        // 2-state, 8-bit signed

    // --- Enumerated type ---
    typedef enum logic [1:0] {
        IDLE   = 2'b00,
        RUN    = 2'b01,
        PAUSE  = 2'b10,
        STOP   = 2'b11
    } state_e;

    state_e current_state;

    // --- Struct type ---
    typedef struct packed {
        logic [15:0] address;
        logic [7:0]  data;
        logic        valid;
        logic [6:0]  tag;
    } packet_t;

    packet_t my_packet;

    // --- Packed and unpacked arrays ---
    logic [3:0][7:0] packed_array;    // 32-bit packed (contiguous bits)
    logic [7:0]      unpacked_array [4]; // 4 separate 8-bit elements

    // --- Constants ---
    localparam int WIDTH = 8;
    localparam logic [7:0] INIT_VAL = 8'hFF;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            my_packet     <= '0;
            current_state <= IDLE;
        end else begin
            my_packet.valid   <= 1'b1;
            my_packet.address <= 16'hCAFE;
            my_packet.data    <= 8'hBE;
            my_packet.tag     <= 7'd42;
        end
    end

    assign result = {current_state, my_packet.address, my_packet.data, 6'b0};

endmodule
