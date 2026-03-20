// Universal Shift Register
// Supports: hold, shift left, shift right, and parallel load.
// Mode encoding: 00 = hold, 01 = shift right, 10 = shift left, 11 = parallel load.

module shift_register #(
    parameter WIDTH = 8
)(
    input  logic             clk,
    input  logic             rst_n,
    input  logic [1:0]       mode,
    input  logic             serial_left_in,   // input for shift-right
    input  logic             serial_right_in,  // input for shift-left
    input  logic [WIDTH-1:0] parallel_in,
    output logic             serial_left_out,
    output logic             serial_right_out,
    output logic [WIDTH-1:0] parallel_out
);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            parallel_out <= '0;
        end else begin
            case (mode)
                2'b00: ; // hold
                2'b01: parallel_out <= {serial_left_in, parallel_out[WIDTH-1:1]};  // shift right
                2'b10: parallel_out <= {parallel_out[WIDTH-2:0], serial_right_in}; // shift left
                2'b11: parallel_out <= parallel_in;                                // load
                default: ;
            endcase
        end
    end

    assign serial_left_out  = parallel_out[WIDTH-1];
    assign serial_right_out = parallel_out[0];

endmodule
