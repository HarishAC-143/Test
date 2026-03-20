// Parameterized Module Examples
// Demonstrates parameter, localparam, generate, and type parameters

// Parameterized adder with configurable width
module adder #(
    parameter int WIDTH = 8
) (
    input  logic [WIDTH-1:0] a,
    input  logic [WIDTH-1:0] b,
    input  logic             cin,
    output logic [WIDTH-1:0] sum,
    output logic             cout
);
    assign {cout, sum} = a + b + cin;
endmodule


// Parameterized register file
module register_file #(
    parameter int DATA_WIDTH = 32,
    parameter int ADDR_WIDTH = 5,
    parameter int NUM_REGS   = 2**ADDR_WIDTH
) (
    input  logic                  clk,
    input  logic                  rst_n,
    input  logic                  wr_en,
    input  logic [ADDR_WIDTH-1:0] wr_addr,
    input  logic [DATA_WIDTH-1:0] wr_data,
    input  logic [ADDR_WIDTH-1:0] rd_addr1,
    input  logic [ADDR_WIDTH-1:0] rd_addr2,
    output logic [DATA_WIDTH-1:0] rd_data1,
    output logic [DATA_WIDTH-1:0] rd_data2
);
    logic [DATA_WIDTH-1:0] regs [NUM_REGS];

    // Write port
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < NUM_REGS; i++)
                regs[i] <= '0;
        end else if (wr_en) begin
            regs[wr_addr] <= wr_data;
        end
    end

    // Read ports (combinational, read-after-write forwarding)
    assign rd_data1 = (wr_en && wr_addr == rd_addr1) ? wr_data : regs[rd_addr1];
    assign rd_data2 = (wr_en && wr_addr == rd_addr2) ? wr_data : regs[rd_addr2];
endmodule


// Parameterized width converter (narrow to wide)
module width_converter #(
    parameter int IN_WIDTH  = 8,
    parameter int OUT_WIDTH = 32
) (
    input  logic                 clk,
    input  logic                 rst_n,
    input  logic [IN_WIDTH-1:0]  data_in,
    input  logic                 valid_in,
    output logic [OUT_WIDTH-1:0] data_out,
    output logic                 valid_out
);
    localparam int RATIO = OUT_WIDTH / IN_WIDTH;
    localparam int CNT_W = $clog2(RATIO);

    logic [CNT_W-1:0]    cnt;
    logic [OUT_WIDTH-1:0] shift_reg;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt       <= '0;
            shift_reg <= '0;
            valid_out <= 1'b0;
        end else begin
            valid_out <= 1'b0;
            if (valid_in) begin
                shift_reg <= {shift_reg[OUT_WIDTH-IN_WIDTH-1:0], data_in};
                if (cnt == RATIO[CNT_W-1:0] - 1) begin
                    cnt       <= '0;
                    valid_out <= 1'b1;
                end else begin
                    cnt <= cnt + 1'b1;
                end
            end
        end
    end

    assign data_out = {shift_reg[OUT_WIDTH-IN_WIDTH-1:0], data_in};
endmodule


// Generate statement: parameterized ripple-carry adder
module ripple_carry_adder #(
    parameter int WIDTH = 8
) (
    input  logic [WIDTH-1:0] a,
    input  logic [WIDTH-1:0] b,
    input  logic             cin,
    output logic [WIDTH-1:0] sum,
    output logic             cout
);
    logic [WIDTH:0] carry;
    assign carry[0] = cin;

    genvar i;
    generate
        for (i = 0; i < WIDTH; i++) begin : gen_full_adder
            full_adder u_fa (
                .a    (a[i]),
                .b    (b[i]),
                .cin  (carry[i]),
                .sum  (sum[i]),
                .cout (carry[i+1])
            );
        end
    endgenerate

    assign cout = carry[WIDTH];
endmodule

module full_adder (
    input  logic a,
    input  logic b,
    input  logic cin,
    output logic sum,
    output logic cout
);
    assign sum  = a ^ b ^ cin;
    assign cout = (a & b) | (a & cin) | (b & cin);
endmodule
