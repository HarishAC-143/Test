// D Flip-Flop Variants
// Demonstrates four common DFF configurations in a single file.

// Basic DFF with asynchronous active-low reset
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

// DFF with synchronous reset (preferred for most FPGA designs)
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

// DFF with clock enable
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

// DFF with set and reset (set has priority)
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
