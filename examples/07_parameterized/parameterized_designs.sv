// Parameterized Arbiter - Round Robin
module round_robin_arbiter #(
    parameter NUM_REQ = 4
)(
    input  logic                 clk,
    input  logic                 rst_n,
    input  logic [NUM_REQ-1:0]   req,
    output logic [NUM_REQ-1:0]   grant
);

    logic [NUM_REQ-1:0] mask, masked_req, next_mask;
    logic [NUM_REQ-1:0] grant_masked, grant_unmasked;

    // Masked request: only consider requests that haven't been served recently
    assign masked_req = req & mask;

    // Priority arbiter for masked requests
    assign grant_masked = masked_req & (~masked_req + 1'b1);

    // Priority arbiter for unmasked requests (fallback)
    assign grant_unmasked = req & (~req + 1'b1);

    // Use masked grant if any masked request exists
    assign grant = (|masked_req) ? grant_masked : grant_unmasked;

    // Update mask after each grant
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            mask <= {NUM_REQ{1'b1}};
        else if (|grant) begin
            if (|masked_req)
                mask <= ~((grant_masked - 1'b1) | grant_masked);
            else
                mask <= ~((grant_unmasked - 1'b1) | grant_unmasked);
        end
    end

endmodule


// Parameterized Clock Divider
module clock_divider #(
    parameter DIV_FACTOR = 10
)(
    input  logic clk,
    input  logic rst_n,
    output logic clk_out
);

    logic [$clog2(DIV_FACTOR)-1:0] count;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count   <= '0;
            clk_out <= 1'b0;
        end else if (count == DIV_FACTOR/2 - 1) begin
            count   <= '0;
            clk_out <= ~clk_out;
        end else begin
            count <= count + 1'b1;
        end
    end

endmodule


// Parameterized Edge Detector
module edge_detector #(
    parameter EDGE_TYPE = "RISING"  // "RISING", "FALLING", or "BOTH"
)(
    input  logic clk,
    input  logic rst_n,
    input  logic signal_in,
    output logic edge_detected
);

    logic signal_d;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            signal_d <= 1'b0;
        else
            signal_d <= signal_in;
    end

    generate
        if (EDGE_TYPE == "RISING")
            assign edge_detected = signal_in & ~signal_d;
        else if (EDGE_TYPE == "FALLING")
            assign edge_detected = ~signal_in & signal_d;
        else
            assign edge_detected = signal_in ^ signal_d;
    endgenerate

endmodule


// Parameterized Debouncer
module debouncer #(
    parameter CLK_FREQ_HZ  = 50_000_000,
    parameter DEBOUNCE_MS   = 20,
    parameter COUNTER_MAX   = CLK_FREQ_HZ / 1000 * DEBOUNCE_MS
)(
    input  logic clk,
    input  logic rst_n,
    input  logic noisy_in,
    output logic clean_out
);

    logic [$clog2(COUNTER_MAX)-1:0] count;
    logic                            input_sync_0, input_sync_1;

    // Double-flop synchronizer
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            input_sync_0 <= 1'b0;
            input_sync_1 <= 1'b0;
        end else begin
            input_sync_0 <= noisy_in;
            input_sync_1 <= input_sync_0;
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count     <= '0;
            clean_out <= 1'b0;
        end else if (input_sync_1 != clean_out) begin
            if (count == COUNTER_MAX - 1) begin
                clean_out <= input_sync_1;
                count     <= '0;
            end else begin
                count <= count + 1'b1;
            end
        end else begin
            count <= '0;
        end
    end

endmodule
