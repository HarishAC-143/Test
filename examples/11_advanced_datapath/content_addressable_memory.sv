// ----------------------------------------------------------------------------
// Content-Addressable Memory (CAM) / Ternary CAM (TCAM)
// Demonstrates: parallel search, priority encoding, mask-based matching,
//               LRU replacement policy, parameterized depth/width
// ----------------------------------------------------------------------------

module ternary_cam #(
    parameter int DATA_WIDTH  = 32,
    parameter int CAM_DEPTH   = 64,
    parameter int PRIORITY    = 1     // 1 = return highest-priority match
)(
    input  logic                           clk,
    input  logic                           rst_n,

    // Search interface
    input  logic [DATA_WIDTH-1:0]          search_key,
    input  logic                           search_valid,
    output logic [$clog2(CAM_DEPTH)-1:0]   match_addr,
    output logic [DATA_WIDTH-1:0]          match_data,
    output logic                           match_found,

    // Write interface
    input  logic [$clog2(CAM_DEPTH)-1:0]   write_addr,
    input  logic [DATA_WIDTH-1:0]          write_data,
    input  logic [DATA_WIDTH-1:0]          write_mask,  // 1 = care, 0 = don't care
    input  logic                           write_en,
    input  logic                           write_valid_bit,

    // Status
    output logic [CAM_DEPTH-1:0]           entry_valid,
    output logic                           cam_full
);

    localparam int ADDR_WIDTH = $clog2(CAM_DEPTH);

    // CAM storage
    logic [DATA_WIDTH-1:0] cam_data [CAM_DEPTH];
    logic [DATA_WIDTH-1:0] cam_mask [CAM_DEPTH];
    logic [CAM_DEPTH-1:0]  valid_bits;

    // Match vector: one bit per entry
    logic [CAM_DEPTH-1:0]  match_vector;

    assign entry_valid = valid_bits;
    assign cam_full    = &valid_bits;

    // Parallel search: compare search_key against all entries simultaneously
    always_comb begin
        for (int i = 0; i < CAM_DEPTH; i++) begin
            match_vector[i] = valid_bits[i] &&
                ((search_key & cam_mask[i]) == (cam_data[i] & cam_mask[i]));
        end
    end

    // Priority encoder: find first (lowest address) match
    always_comb begin
        match_addr  = '0;
        match_data  = '0;
        match_found = 1'b0;

        if (search_valid && |match_vector) begin
            match_found = 1'b1;

            if (PRIORITY) begin
                // Lowest-address priority
                for (int i = CAM_DEPTH - 1; i >= 0; i--) begin
                    if (match_vector[i]) begin
                        match_addr = i[ADDR_WIDTH-1:0];
                        match_data = cam_data[i];
                    end
                end
            end else begin
                // Highest-address priority
                for (int i = 0; i < CAM_DEPTH; i++) begin
                    if (match_vector[i]) begin
                        match_addr = i[ADDR_WIDTH-1:0];
                        match_data = cam_data[i];
                    end
                end
            end
        end
    end

    // Write logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_bits <= '0;
            for (int i = 0; i < CAM_DEPTH; i++) begin
                cam_data[i] <= '0;
                cam_mask[i] <= '1;  // Default: all bits are "care"
            end
        end else if (write_en) begin
            cam_data[write_addr]   <= write_data;
            cam_mask[write_addr]   <= write_mask;
            valid_bits[write_addr] <= write_valid_bit;
        end
    end

endmodule
