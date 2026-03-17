// Serial-In Serial-Out (SISO) Shift Register
module siso_shift_reg #(
    parameter WIDTH = 8
)(
    input  logic clk,
    input  logic rst_n,
    input  logic serial_in,
    output logic serial_out
);

    logic [WIDTH-1:0] shift_reg;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            shift_reg <= '0;
        else
            shift_reg <= {shift_reg[WIDTH-2:0], serial_in};
    end

    assign serial_out = shift_reg[WIDTH-1];

endmodule


// Parallel-In Serial-Out (PISO) Shift Register
module piso_shift_reg #(
    parameter WIDTH = 8
)(
    input  logic             clk,
    input  logic             rst_n,
    input  logic             load,
    input  logic [WIDTH-1:0] parallel_in,
    output logic             serial_out
);

    logic [WIDTH-1:0] shift_reg;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            shift_reg <= '0;
        else if (load)
            shift_reg <= parallel_in;
        else
            shift_reg <= {shift_reg[WIDTH-2:0], 1'b0};
    end

    assign serial_out = shift_reg[WIDTH-1];

endmodule


// Serial-In Parallel-Out (SIPO) Shift Register
module sipo_shift_reg #(
    parameter WIDTH = 8
)(
    input  logic             clk,
    input  logic             rst_n,
    input  logic             serial_in,
    output logic [WIDTH-1:0] parallel_out,
    output logic             valid
);

    logic [$clog2(WIDTH):0] count;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            parallel_out <= '0;
            count        <= '0;
        end else begin
            parallel_out <= {parallel_out[WIDTH-2:0], serial_in};
            if (count < WIDTH)
                count <= count + 1;
        end
    end

    assign valid = (count == WIDTH[$clog2(WIDTH):0]);

endmodule


// Universal Shift Register with bidirectional shift
module universal_shift_reg #(
    parameter WIDTH = 8
)(
    input  logic             clk,
    input  logic             rst_n,
    input  logic [1:0]       mode,       // 00=hold, 01=shift_right, 10=shift_left, 11=parallel_load
    input  logic             serial_in_l, // left serial input (for right shift)
    input  logic             serial_in_r, // right serial input (for left shift)
    input  logic [WIDTH-1:0] parallel_in,
    output logic [WIDTH-1:0] parallel_out
);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            parallel_out <= '0;
        else begin
            case (mode)
                2'b00: parallel_out <= parallel_out;
                2'b01: parallel_out <= {serial_in_l, parallel_out[WIDTH-1:1]};
                2'b10: parallel_out <= {parallel_out[WIDTH-2:0], serial_in_r};
                2'b11: parallel_out <= parallel_in;
            endcase
        end
    end

endmodule
