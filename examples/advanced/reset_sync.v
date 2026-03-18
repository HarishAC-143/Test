// =============================================================================
// Advanced Example: Reset Synchronizer
// =============================================================================
//
// When an asynchronous reset needs to be used in a clock domain that is
// different from where the reset originates, it must be synchronized.
//
// The standard pattern is:
//   - Assert reset ASYNCHRONOUSLY (immediate effect)
//   - De-assert reset SYNCHRONOUSLY (aligned to destination clock)
//
// This prevents reset de-assertion from violating the recovery/removal
// timing of flip-flops in the destination domain.
//
// SpyGlass RDC rules: Ar_rdc01, Ar_rdc02
// =============================================================================

// =============================================================================
// WRONG: Unsynchronized reset crossing
// =============================================================================
module reset_unsync (
    input  clk_b,
    input  rst_a_n,     // Reset from clk_a domain
    output rst_b_n      // Used in clk_b domain — UNSYNCHRONIZED!
);
    // Ar_rdc01 VIOLATION:
    // rst_a_n de-asserts asynchronously relative to clk_b.
    // If it de-asserts near a clk_b edge, some flops in the clk_b
    // domain may come out of reset one cycle before others,
    // causing inconsistent initial state.
    assign rst_b_n = rst_a_n;
endmodule


// =============================================================================
// CORRECT: Reset synchronizer (async assert, sync de-assert)
// =============================================================================
module reset_sync (
    input  clk_b,       // Destination clock
    input  rst_a_n,     // Asynchronous reset from another domain
    output rst_b_n      // Synchronized reset for clk_b domain
);

    reg sync_ff1, sync_ff2;

    // The key insight: the asynchronous reset input drives the
    // async reset pins of the synchronizer flip-flops. This means:
    //
    //   ASSERTION (rst_a_n goes low):
    //     Both sync_ff1 and sync_ff2 are immediately forced to 0.
    //     rst_b_n goes low within one gate delay — no metastability.
    //
    //   DE-ASSERTION (rst_a_n goes high):
    //     The async reset is released. sync_ff1 sees logic 1 on its D input
    //     (tied to VDD). On the next clk_b rising edge, sync_ff1 goes high.
    //     On the following clk_b edge, sync_ff2 goes high.
    //     rst_b_n de-asserts synchronously, aligned to clk_b.
    //
    always @(posedge clk_b or negedge rst_a_n) begin
        if (!rst_a_n) begin
            sync_ff1 <= 1'b0;  // Async assert
            sync_ff2 <= 1'b0;  // Async assert
        end else begin
            sync_ff1 <= 1'b1;  // D input tied to 1
            sync_ff2 <= sync_ff1;
        end
    end

    assign rst_b_n = sync_ff2;

endmodule


// =============================================================================
// Complete Example: Multi-domain reset distribution
// =============================================================================
module reset_distribution (
    input  clk_core,     // 100 MHz core clock
    input  clk_peri,     // 50 MHz peripheral clock
    input  clk_io,       // 200 MHz I/O clock
    input  por_n,        // Power-on reset (asynchronous, active low)
    output rst_core_n,   // Synchronized reset for core domain
    output rst_peri_n,   // Synchronized reset for peripheral domain
    output rst_io_n      // Synchronized reset for I/O domain
);

    // Each domain gets its own reset synchronizer instance.
    // All see the same asynchronous assert, but each de-asserts
    // synchronously to its own clock.
    reset_sync u_rst_core (
        .clk_b   (clk_core),
        .rst_a_n (por_n),
        .rst_b_n (rst_core_n)
    );

    reset_sync u_rst_peri (
        .clk_b   (clk_peri),
        .rst_a_n (por_n),
        .rst_b_n (rst_peri_n)
    );

    reset_sync u_rst_io (
        .clk_b   (clk_io),
        .rst_a_n (por_n),
        .rst_b_n (rst_io_n)
    );

endmodule
