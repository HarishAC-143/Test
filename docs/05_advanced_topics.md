# Chapter 5: Advanced Topics

## 5.1 Hierarchical Analysis with Abstracts

For large SoC designs with millions of gates, flat analysis is impractical. SpyGlass supports **hierarchical analysis** using abstracts.

### What is an Abstract?

An abstract is a compact representation of a block's interface behavior without its internal implementation. It captures:

- Clock domain information
- CDC crossing characteristics
- Port-level lint attributes

### Creating Abstracts

```tcl
# Step 1: Analyze the sub-block
read_file -type verilog {sub_block.v}
set_option top sub_block
current_goal lint/lint_abstract
run_goal

# Step 2: Generate the abstract
generate_abstract -output sub_block.sgabs
```

### Using Abstracts in Top-Level Analysis

```tcl
# Top-level project file
read_file -type verilog {top.v}
read_file -type sgabs {sub_block.sgabs}  # Use abstract instead of RTL
set_option top top_module
current_goal lint/lint_rtl
run_goal
```

### Benefits

| Aspect | Flat Analysis | Hierarchical |
|--------|--------------|-------------|
| Runtime | Hours | Minutes |
| Memory | 50+ GB | 5-10 GB |
| Accuracy | Full | Slightly reduced at boundaries |
| Suitability | Block-level | SoC-level |

## 5.2 Waiver Management Best Practices

### Waiver File Organization

```
waivers/
├── block_level/
│   ├── cpu_core_waivers.swl
│   ├── dma_engine_waivers.swl
│   └── uart_waivers.swl
├── chip_level/
│   └── soc_top_waivers.swl
└── common/
    └── standard_cell_waivers.swl
```

### Waiver Syntax Reference

```tcl
# Waive by rule and module
waive -rule W_0123 -module my_module \
    -comment "Intentionally unloaded debug port"

# Waive by rule, module, and signal
waive -rule W_0110 -module my_module -signal data_bus \
    -comment "Width mismatch is intentional — upper bits unused"

# Waive by rule with regex pattern
waive -rule W_0123 -module {test_*} \
    -comment "Test modules have intentionally unloaded signals"

# Waive CDC violation with from/to specification
waive -rule Ac_cdc01 \
    -from {cfg_reg[*]} -to {sync_cfg[*]} \
    -comment "Quasi-static configuration — stable during operation"

# Conditional waiver (only for specific configurations)
waive -rule W_0408 -module legacy_block \
    -comment "Legacy IP — latch is intentional per design spec v2.3"
```

### Waiver Review Process

1. Every waiver must have a meaningful `-comment`
2. Waivers should be reviewed in code review (treat them like RTL changes)
3. Track waiver count over time — increasing count is a red flag
4. Periodically audit waivers — remove stale ones after RTL changes

## 5.3 Regression and CI/CD Integration

### Regression Script

```bash
#!/bin/bash
# run_spyglass_regression.sh

set -e

SPYGLASS="spyglass"
BLOCKS="cpu_core dma_engine uart_ctrl memory_ctrl"
PASS=0
FAIL=0

for block in $BLOCKS; do
    echo "========================================="
    echo "Running SpyGlass on: $block"
    echo "========================================="

    $SPYGLASS -project projects/${block}.prj -batch -goal lint/lint_rtl 2>&1 | \
        tee logs/${block}_lint.log

    # Check for remaining violations (non-waived)
    remaining=$(grep "Remaining" logs/${block}_lint.log | awk '{print $NF}')

    if [ "$remaining" -eq 0 ] 2>/dev/null; then
        echo "PASS: $block — 0 remaining violations"
        PASS=$((PASS + 1))
    else
        echo "FAIL: $block — $remaining remaining violations"
        FAIL=$((FAIL + 1))
    fi
done

echo ""
echo "========================================="
echo "Regression Summary: $PASS passed, $FAIL failed"
echo "========================================="

exit $FAIL
```

### CI/CD Pipeline Example (GitHub Actions)

```yaml
# .github/workflows/spyglass.yml
name: SpyGlass Lint & CDC

on:
  pull_request:
    paths:
      - 'rtl/**'
      - 'spyglass/**'

jobs:
  spyglass-lint:
    runs-on: self-hosted  # Requires SpyGlass license
    steps:
      - uses: actions/checkout@v4
      - name: Setup SpyGlass
        run: source /tools/synopsys/spyglass/setup.sh
      - name: Run Lint
        run: |
          cd spyglass
          spyglass -project lint.prj -batch -goal lint/lint_rtl
      - name: Check Results
        run: |
          python3 scripts/check_spyglass_results.py \
            --report spyglass_work/consolidated_reports/lint_rtl_summary.rpt \
            --max-errors 0 \
            --max-warnings 0
      - name: Upload Reports
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: spyglass-reports
          path: spyglass/spyglass_work/consolidated_reports/
```

## 5.4 Custom Rule Development

SpyGlass allows custom rules using the **SpyGlass Rule Development Kit (RDK)**:

### Simple Custom Rule (TCL)

```tcl
# custom_rules/no_initial_blocks.tcl

proc check_no_initial {} {
    set violations {}

    foreach_module {mod} {
        foreach_process {proc} -module $mod {
            if {[get_attribute $proc type] eq "initial"} {
                lappend violations [list $mod $proc \
                    "Initial blocks are not synthesizable"]
            }
        }
    }

    return $violations
}
```

### Registering Custom Rules

```tcl
# In the project file
set_option custom_rules_dir ./custom_rules
set_rule_status -enable CUSTOM_001
```

## 5.5 Multi-Mode / Multi-Corner Analysis

For designs with multiple operating modes:

```tcl
# Mode 1: Normal operation
set_mode normal
read_file -type sgdc constraints/normal_mode.sgdc
current_goal cdc/cdc_verify
run_goal

# Mode 2: Low-power mode
set_mode low_power
read_file -type sgdc constraints/low_power_mode.sgdc
current_goal cdc/cdc_verify
run_goal
```

## 5.6 Power Intent Verification

SpyGlass integrates with UPF (Unified Power Format) for power-aware CDC:

```tcl
# Read UPF
read_file -type upf power/chip.upf

# Power-aware CDC will check:
# - CDC paths that cross power domains
# - Isolation cell requirements
# - Level shifter requirements
# - Retention register constraints
current_goal cdc/cdc_verify
set_option power_aware_cdc yes
run_goal
```

## 5.7 SpyGlass with SystemVerilog

SpyGlass fully supports SystemVerilog constructs:

```tcl
# Enable SystemVerilog
set_option enableSV yes

# Read SystemVerilog files
read_file -type systemverilog {
    rtl/pkg_defs.sv
    rtl/interface_bus.sv
    rtl/top_module.sv
}
```

### SV-Specific Lint Rules

| Rule | Description |
|------|-------------|
| `SV_0001` | Interface port not properly connected |
| `SV_0002` | Package import unused |
| `SV_0003` | Assertion without action block |
| `SV_0004` | Unique/priority case without all values covered |

## 5.8 Common Pitfalls and How to Avoid Them

### Pitfall 1: Ignoring Lint Before CDC

Always run lint first. Many CDC false positives are caused by lint issues (e.g., undriven signals create phantom CDC paths).

```
Recommended flow:
  1. lint/lint_rtl        → Fix all errors
  2. lint/lint_rtl        → Re-run, verify clean
  3. cdc/cdc_verify_struct → Fix structural CDC issues
  4. cdc/cdc_verify       → Fix protocol CDC issues
  5. Sign off
```

### Pitfall 2: Incomplete SGDC Constraints

Missing clock definitions cause SpyGlass to infer clocks (often incorrectly), leading to false violations or missed real issues.

**Check:** Run `report_clock` after loading constraints to verify all clocks are defined.

### Pitfall 3: Over-Waiving

Waiving too aggressively masks real bugs. Rules:
- Never waive an entire rule globally
- Always include a technical justification
- Review waiver count trends

### Pitfall 4: Not Constraining Generated Clocks

Generated clocks (dividers, PLLs, muxed clocks) need explicit constraints:

```tcl
# Generated clock
create_generated_clock -name clk_div2 \
    -source [get_ports clk_sys] \
    -divide_by 2 \
    [get_pins divider/clk_out]

# Muxed clock
create_generated_clock -name clk_mux_out \
    -source [get_ports clk_a] \
    -combinational \
    [get_pins clk_mux/out]
```

### Pitfall 5: Treating SpyGlass as a One-Time Check

SpyGlass should be run continuously:
- On every RTL commit (CI/CD)
- Before every tape-out milestone
- After any clock tree or reset tree change
- After adding new IP blocks

## 5.9 SpyGlass Command Reference

### Frequently Used TCL Commands

| Command | Description |
|---------|-------------|
| `read_file -type verilog {files}` | Read Verilog files |
| `read_file -type systemverilog {files}` | Read SystemVerilog files |
| `read_file -type sgdc {file}` | Read SGDC constraints |
| `read_file -type waiver {file}` | Read waiver file |
| `set_option top module_name` | Set top module |
| `set_option enableSV yes` | Enable SystemVerilog |
| `current_goal goal_name` | Select analysis goal |
| `run_goal` | Execute current goal |
| `set_rule_status -disable rule_id` | Disable a rule |
| `set_rule_status -enable rule_id` | Enable a rule |
| `report_clock` | Report detected clocks |
| `report_crossing` | Report CDC crossings |
| `generate_abstract` | Create block abstract |
| `set_option projectwdir dir` | Set working directory |
| `set_option incr_mode yes` | Enable incremental mode |

### Command-Line Options

| Option | Description |
|--------|-------------|
| `-project file.prj` | Specify project file |
| `-batch` | Run in batch mode (no GUI) |
| `-goal goal_name` | Override project file goal |
| `-tcl` | Interactive TCL mode |
| `-version` | Print version info |
| `-license_wait` | Wait for license if busy |
| `-max_violations N` | Stop after N violations |

## 5.10 Conclusion

SpyGlass Lint and CDC are essential tools in the modern ASIC/FPGA design flow. By integrating them early and running them continuously, teams can:

- Catch bugs weeks before simulation finds them
- Eliminate entire classes of silicon failures (metastability, latches)
- Enforce consistent coding standards across teams
- Achieve faster time-to-tapeout with higher confidence

The key to success is treating SpyGlass results with the same rigor as functional verification results — track them, fix them, waive them with justification, and never let the count grow unchecked.
