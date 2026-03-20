// ============================================================================
// Conditional Architecture using Generate-If
// ============================================================================
// Demonstrates `generate if` to select between synchronous and asynchronous
// reset styles at elaboration time. The parameter ASYNC_RESET controls
// which architecture is instantiated.
// ============================================================================

module sync_or_async_reset #(
    parameter bit ASYNC_RESET = 1
)(
    input  logic clk,
    input  logic rst_n,
    input  logic [7:0] d,
    output logic [7:0] q
);

    generate
        if (ASYNC_RESET) begin : gen_async
            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n)
                    q <= 8'h00;
                else
                    q <= d;
            end
        end else begin : gen_sync
            always_ff @(posedge clk) begin
                if (!rst_n)
                    q <= 8'h00;
                else
                    q <= d;
            end
        end
    endgenerate

endmodule


// ============================================================================
// Generate-Case: Select implementation by parameter
// ============================================================================

module multiplier_wrapper #(
    parameter int WIDTH = 16,
    parameter string IMPL = "BEHAVIORAL"  // "BEHAVIORAL" or "DSP"
)(
    input  logic              clk,
    input  logic [WIDTH-1:0]  a, b,
    output logic [2*WIDTH-1:0] product
);

    generate
        case (IMPL)
            "DSP": begin : gen_dsp
                // Registered multiply — maps to DSP slices in FPGA
                always_ff @(posedge clk) begin
                    product <= a * b;
                end
            end

            default: begin : gen_behav
                // Pure combinational multiply
                assign product = a * b;
            end
        endcase
    endgenerate

endmodule
