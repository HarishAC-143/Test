// D Flip-Flop Variants
// Demonstrates various sequential element configurations

// Basic D Flip-Flop with asynchronous active-low reset
module dff_async_reset (
    input  logic clk,
    input  logic rst_n,
    input  logic d,
    output logic q
);
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            q <= 1'b0;
        else
            q <= d;
    end
endmodule


// D Flip-Flop with synchronous reset
module dff_sync_reset (
    input  logic clk,
    input  logic rst_n,
    input  logic d,
    output logic q
);
    always_ff @(posedge clk) begin
        if (!rst_n)
            q <= 1'b0;
        else
            q <= d;
    end
endmodule


// D Flip-Flop with enable
module dff_enable (
    input  logic clk,
    input  logic rst_n,
    input  logic en,
    input  logic d,
    output logic q
);
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            q <= 1'b0;
        else if (en)
            q <= d;
    end
endmodule


// D Flip-Flop with set and reset (set has priority)
module dff_set_reset (
    input  logic clk,
    input  logic rst_n,
    input  logic set,
    input  logic d,
    output logic q
);
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            q <= 1'b0;
        else if (set)
            q <= 1'b1;
        else
            q <= d;
    end
endmodule


// Parameterized register with byte-enable
module register_byte_en #(
    parameter int WIDTH = 32
) (
    input  logic                   clk,
    input  logic                   rst_n,
    input  logic [WIDTH/8-1:0]     byte_en,
    input  logic [WIDTH-1:0]       d,
    output logic [WIDTH-1:0]       q
);
    genvar i;
    generate
        for (i = 0; i < WIDTH/8; i++) begin : gen_byte_lane
            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n)
                    q[i*8 +: 8] <= '0;
                else if (byte_en[i])
                    q[i*8 +: 8] <= d[i*8 +: 8];
            end
        end
    endgenerate
endmodule
