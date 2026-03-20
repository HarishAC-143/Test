// Priority encoder — finds the highest-set bit.
// Parameterized width with valid output flag.

module priority_encoder #(
    parameter int WIDTH = 8
)(
    input  logic [WIDTH-1:0]          request,
    output logic [$clog2(WIDTH)-1:0]  index,
    output logic                      valid
);

    always_comb begin
        index = '0;
        valid = 1'b0;

        for (int i = 0; i < WIDTH; i++) begin
            if (request[i]) begin
                index = $clog2(WIDTH)'(i);
                valid = 1'b1;
            end
        end
    end

endmodule
