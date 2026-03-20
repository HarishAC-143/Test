// Parameterized shift register with parallel load and serial I/O.

module shift_register #(
    parameter int WIDTH = 8
)(
    input  logic             clk,
    input  logic             rst_n,
    input  logic             enable,
    input  logic             load,        // parallel load
    input  logic [WIDTH-1:0] par_in,      // parallel input
    input  logic             serial_in,   // serial input (shifted into MSB)
    input  logic             direction,   // 1 = left, 0 = right
    output logic [WIDTH-1:0] par_out,     // parallel output
    output logic             serial_out   // serial output
);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            par_out <= '0;
        end else if (load) begin
            par_out <= par_in;
        end else if (enable) begin
            if (direction) begin
                par_out <= {par_out[WIDTH-2:0], serial_in};  // shift left
            end else begin
                par_out <= {serial_in, par_out[WIDTH-1:1]};  // shift right
            end
        end
    end

    assign serial_out = direction ? par_out[WIDTH-1] : par_out[0];

endmodule
