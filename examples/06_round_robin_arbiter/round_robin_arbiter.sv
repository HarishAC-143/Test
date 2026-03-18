// Round-Robin Arbiter
// Fair arbitration for N requestors with rotating priority.
// Supports burst locking via the lock signal.

module round_robin_arbiter #(
    parameter int N = 4
) (
    input  logic         clk,
    input  logic         rst_n,
    input  logic [N-1:0] req,       // Request signals
    input  logic         lock,      // Hold current grant (for bursts)
    output logic [N-1:0] grant,     // One-hot grant
    output logic         valid      // A grant is active
);

    logic [N-1:0] mask;        // Priority mask (thermometer code)
    logic [N-1:0] masked_req;  // Requests after applying mask
    logic [N-1:0] grant_masked;
    logic [N-1:0] grant_unmasked;
    logic         mask_valid;

    // Apply round-robin mask: zero out previously-served requestors
    assign masked_req = req & mask;

    // Priority encoder for masked requests (first set bit from LSB)
    function automatic logic [N-1:0] priority_encode(input logic [N-1:0] r);
        return r & (~r + 1);  // Isolate lowest set bit
    endfunction

    assign grant_masked   = priority_encode(masked_req);
    assign grant_unmasked = priority_encode(req);

    // Use masked result if any masked request exists, otherwise wrap around
    assign mask_valid = |masked_req;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            grant <= '0;
            valid <= 1'b0;
            mask  <= {N{1'b1}};  // All requestors have priority initially
        end else if (lock && valid) begin
            // Hold current grant during burst
        end else if (|req) begin
            if (mask_valid) begin
                grant <= grant_masked;
            end else begin
                grant <= grant_unmasked;
            end
            valid <= 1'b1;

            // Update mask: clear all bits at and below the granted position
            // This gives next-higher requestor the highest priority
            if (mask_valid) begin
                mask <= {N{1'b1}} << ($clog2(N)'(find_bit_pos(grant_masked)) + 1);
            end else begin
                mask <= {N{1'b1}} << ($clog2(N)'(find_bit_pos(grant_unmasked)) + 1);
            end
        end else begin
            grant <= '0;
            valid <= 1'b0;
        end
    end

    // Find the position of the single set bit in a one-hot vector
    function automatic int find_bit_pos(input logic [N-1:0] one_hot);
        for (int i = 0; i < N; i++) begin
            if (one_hot[i]) return i;
        end
        return 0;
    endfunction

endmodule
