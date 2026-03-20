// Binary-to-one-hot decoder.
// N-bit input produces 2^N-bit one-hot output.

module decoder #(
    parameter int WIDTH = 3
)(
    input  logic [WIDTH-1:0]     encoded,
    input  logic                 enable,
    output logic [(1<<WIDTH)-1:0] decoded
);

    always_comb begin
        decoded = '0;
        if (enable)
            decoded[encoded] = 1'b1;
    end

endmodule
