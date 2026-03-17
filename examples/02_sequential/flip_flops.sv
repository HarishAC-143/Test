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


// D Flip-Flop with asynchronous reset
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


// D Flip-Flop with enable and async reset
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


// T (Toggle) Flip-Flop
module tff (
    input  logic clk,
    input  logic rst_n,
    input  logic t,
    output logic q
);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            q <= 1'b0;
        else if (t)
            q <= ~q;
    end

endmodule


// JK Flip-Flop
module jkff (
    input  logic clk,
    input  logic rst_n,
    input  logic j,
    input  logic k,
    output logic q
);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            q <= 1'b0;
        else begin
            case ({j, k})
                2'b00: q <= q;      // Hold
                2'b01: q <= 1'b0;   // Reset
                2'b10: q <= 1'b1;   // Set
                2'b11: q <= ~q;     // Toggle
            endcase
        end
    end

endmodule
