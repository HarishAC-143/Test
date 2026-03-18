// =============================================================================
// Advanced Example: CDC Reconvergence (Ac_cdc03)
// =============================================================================
//
// SpyGlass Rule: Ac_cdc03
// Severity:      Warning
// Category:      Clock Domain Crossing
//
// Reconvergence occurs when a signal from one clock domain is synchronized
// through two or more independent paths, and those paths later converge
// (feed into the same logic). Even though each path is individually
// synchronized, the synchronizer latency is non-deterministic (can be
// N or N+1 cycles). This means the converging signals may represent
// different snapshots in time, causing logical inconsistency.
//
// =============================================================================

// =============================================================================
// WRONG: Reconvergent CDC paths
// =============================================================================
module reconvergence_buggy (
    input  clk_a,
    input  rst_a_n,
    input  clk_b,
    input  rst_b_n,
    input  sig_from_a,
    output result
);

    reg reg_a;

    // Source domain register
    always @(posedge clk_a or negedge rst_a_n) begin
        if (!rst_a_n)
            reg_a <= 1'b0;
        else
            reg_a <= sig_from_a;
    end

    // Path 1: synchronize reg_a through synchronizer chain 1
    reg sync1_p1, sync2_p1;
    always @(posedge clk_b or negedge rst_b_n) begin
        if (!rst_b_n) begin
            sync1_p1 <= 1'b0;
            sync2_p1 <= 1'b0;
        end else begin
            sync1_p1 <= reg_a;
            sync2_p1 <= sync1_p1;
        end
    end

    // Path 2: synchronize the SAME reg_a through a separate synchronizer
    reg sync1_p2, sync2_p2;
    always @(posedge clk_b or negedge rst_b_n) begin
        if (!rst_b_n) begin
            sync1_p2 <= 1'b0;
            sync2_p2 <= 1'b0;
        end else begin
            sync1_p2 <= reg_a;
            sync2_p2 <= sync1_p2;
        end
    end

    // Ac_cdc03 VIOLATION: Reconvergence!
    // sync2_p1 and sync2_p2 both represent reg_a, but they may
    // be offset by one clk_b cycle due to independent synchronizer
    // latency. If reg_a transitions from 0 to 1:
    //   - sync2_p1 might show '1' (captured the transition)
    //   - sync2_p2 might still show '0' (captured one cycle later)
    // The XOR would output '1' — a spurious pulse!
    assign result = sync2_p1 ^ sync2_p2;

endmodule


// =============================================================================
// CORRECT: Avoid reconvergence — synchronize once, then fan out
// =============================================================================
module reconvergence_fixed (
    input  clk_a,
    input  rst_a_n,
    input  clk_b,
    input  rst_b_n,
    input  sig_from_a,
    output result
);

    reg reg_a;

    always @(posedge clk_a or negedge rst_a_n) begin
        if (!rst_a_n)
            reg_a <= 1'b0;
        else
            reg_a <= sig_from_a;
    end

    // Single synchronization path
    reg sync1, sync2;
    always @(posedge clk_b or negedge rst_b_n) begin
        if (!rst_b_n) begin
            sync1 <= 1'b0;
            sync2 <= 1'b0;
        end else begin
            sync1 <= reg_a;
            sync2 <= sync1;
        end
    end

    // Fan out AFTER synchronization — both consumers see the same value
    // at the same time. No reconvergence issue.
    wire use_path1 = sync2;
    wire use_path2 = sync2;

    // This XOR will always be 0 because both paths see the identical value.
    assign result = use_path1 ^ use_path2;

endmodule


// =============================================================================
// CORRECT: For genuinely independent signals, synchronize each separately
// =============================================================================
module independent_signals (
    input  clk_a,
    input  rst_a_n,
    input  clk_b,
    input  rst_b_n,
    input  sig_x,      // Truly independent signal X
    input  sig_y,      // Truly independent signal Y
    output result
);

    reg reg_x, reg_y;

    always @(posedge clk_a or negedge rst_a_n) begin
        if (!rst_a_n) begin
            reg_x <= 1'b0;
            reg_y <= 1'b0;
        end else begin
            reg_x <= sig_x;
            reg_y <= sig_y;
        end
    end

    // Separate synchronizers for genuinely independent signals — this is fine.
    // The key question SpyGlass asks: if these signals converge downstream,
    // is the design tolerant of them arriving at different times?
    reg sync1_x, sync2_x;
    reg sync1_y, sync2_y;

    always @(posedge clk_b or negedge rst_b_n) begin
        if (!rst_b_n) begin
            sync1_x <= 1'b0;
            sync2_x <= 1'b0;
            sync1_y <= 1'b0;
            sync2_y <= 1'b0;
        end else begin
            sync1_x <= reg_x;
            sync2_x <= sync1_x;
            sync1_y <= reg_y;
            sync2_y <= sync1_y;
        end
    end

    // If X and Y are truly independent, their convergence here is safe
    // because no logical relationship exists between them.
    assign result = sync2_x & sync2_y;

endmodule
