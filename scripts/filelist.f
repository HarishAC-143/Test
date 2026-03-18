// =============================================================================
// Design File List
// =============================================================================
// This .f file lists all RTL source files for SpyGlass analysis.
// Usage: read_file -type sourcelist scripts/filelist.f
//        or: spyglass -batch -f scripts/filelist.f
//
// Order: Dependencies must appear before modules that instantiate them.
// =============================================================================

// --- Utility / library modules (no dependencies) ---
examples/practical/reset_synchronizer.v
examples/practical/async_fifo.v

// --- Lint issue examples ---
examples/lint_issues/counter_with_issues.v
examples/lint_issues/latch_and_combo.v
examples/lint_issues/fsm_issues.v

// --- CDC issue examples ---
examples/cdc_issues/cdc_missing_sync.v
examples/cdc_issues/cdc_multibit_bad.v
examples/cdc_issues/cdc_combo_before_sync.v

// --- Fixed lint examples ---
examples/lint_fixed/counter_fixed.v
examples/lint_fixed/latch_and_combo_fixed.v
examples/lint_fixed/fsm_fixed.v

// --- Fixed CDC examples ---
examples/cdc_fixed/cdc_with_sync.v
examples/cdc_fixed/cdc_multibit_gray.v
examples/cdc_fixed/cdc_combo_fixed.v

// --- Practical / system-level examples ---
examples/practical/multi_clock_system.v
