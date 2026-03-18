# Altera FPGA Regression Test Automation: A Comprehensive Tutorial

## Table of Contents

1. [Introduction](#1-introduction)
2. [Prerequisites and Environment Setup](#2-prerequisites-and-environment-setup)
3. [Understanding the FPGA Design Flow](#3-understanding-the-fpga-design-flow)
4. [Regression Testing Fundamentals](#4-regression-testing-fundamentals)
5. [Project Structure and Organization](#5-project-structure-and-organization)
6. [RTL Design Examples](#6-rtl-design-examples)
7. [Testbench Development](#7-testbench-development)
8. [Tcl-Based Quartus Automation](#8-tcl-based-quartus-automation)
9. [Shell Script Orchestration](#9-shell-script-orchestration)
10. [Makefile-Based Regression Flow](#10-makefile-based-regression-flow)
11. [Python-Based Result Parsing and Reporting](#11-python-based-result-parsing-and-reporting)
12. [Timing Constraint Management](#12-timing-constraint-management)
13. [CI/CD Integration](#13-cicd-integration)
14. [Advanced Regression Strategies](#14-advanced-regression-strategies)
15. [Debugging and Troubleshooting](#15-debugging-and-troubleshooting)
16. [Best Practices](#16-best-practices)

---

## 1. Introduction

Regression test automation for Altera (now Intel) FPGAs is the practice of systematically
re-running synthesis, place-and-route, timing analysis, and functional simulation flows
every time the RTL source, constraints, or tool settings change. The goal is to catch
breakages early — whether they manifest as synthesis failures, timing violations, resource
overflows, or functional bugs — before they propagate downstream.

### Why Automate FPGA Regression Testing?

| Challenge | Manual Approach | Automated Approach |
|---|---|---|
| Build consistency | Engineer remembers settings | Scripts enforce settings |
| Timing closure tracking | Spot-checked occasionally | Every commit is analyzed |
| Resource utilization | Noticed when device is full | Trend graphs catch creep |
| Multi-device support | Rarely tested on all targets | Matrix builds cover all targets |
| Nightly/CI verification | Skipped under schedule pressure | Runs automatically |

### What This Tutorial Covers

This tutorial walks through the complete automation stack:

- **RTL examples** — small but realistic designs used as regression targets
- **Testbenches** — SystemVerilog testbenches that self-check with pass/fail status
- **Tcl automation** — scripts that drive Quartus Prime from the command line
- **Shell orchestration** — Bash scripts that manage parallel builds and collect results
- **Makefile flow** — `make`-based interface for common regression operations
- **Python reporting** — parsing logs, generating HTML/JSON reports, trend analysis
- **CI/CD integration** — GitHub Actions and Jenkins pipeline definitions
- **Constraint management** — SDC files and multi-corner timing strategies

---

## 2. Prerequisites and Environment Setup

### Required Software

| Tool | Version | Purpose |
|---|---|---|
| Quartus Prime | 23.1+ (Lite/Standard/Pro) | Synthesis, P&R, timing analysis |
| ModelSim / Questa | Bundled or standalone | RTL simulation |
| Python | 3.8+ | Report generation, log parsing |
| GNU Make | 4.0+ | Build orchestration |
| Bash | 4.0+ | Shell scripting |
| Git | 2.30+ | Version control |

### Environment Variables

Set these in your shell profile (`~/.bashrc` or `~/.profile`):

```bash
# Quartus Prime installation
export QUARTUS_ROOTDIR="/opt/intelFPGA/23.1/quartus"
export PATH="${QUARTUS_ROOTDIR}/bin:${PATH}"

# ModelSim / Questa
export MODELSIM_ROOT="/opt/intelFPGA/23.1/modelsim_ase"
export PATH="${MODELSIM_ROOT}/bin:${PATH}"

# License (node-locked or floating)
export LM_LICENSE_FILE="1800@license-server.example.com"

# Project-specific
export FPGA_REGRESS_ROOT="$(pwd)"
```

### Verifying the Installation

```bash
# Check Quartus availability
quartus_sh --version

# Check ModelSim availability
vsim -version

# Check Python
python3 --version
```

---

## 3. Understanding the FPGA Design Flow

The Altera/Intel FPGA design flow consists of these major stages, each of which
can be individually automated and regression-tested:

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌──────────────┐
│  Analysis &  │───>│  Synthesis  │───>│   Fitter    │───>│   Timing     │
│  Elaboration │    │  (quartus_  │    │  (quartus_  │    │   Analysis   │
│  (quartus_   │    │   syn)      │    │   fit)      │    │  (quartus_   │
│   map)       │    │             │    │             │    │   sta)       │
└─────────────┘    └─────────────┘    └─────────────┘    └──────────────┘
       │                                                        │
       │                                                        v
       │                                                 ┌──────────────┐
       │                                                 │  Assembler   │
       │                                                 │  (quartus_   │
       │                                                 │   asm)       │
       │                                                 └──────────────┘
       v                                                        │
┌─────────────┐                                                 v
│  Simulation  │                                         ┌──────────────┐
│  (ModelSim/  │                                         │  Programming │
│   Questa)    │                                         │  (quartus_   │
└─────────────┘                                         │   pgm)       │
                                                         └──────────────┘
```

### Regression Checkpoints

Each stage produces artifacts and metrics that regression testing validates:

| Stage | Key Artifacts | Regression Checks |
|---|---|---|
| Analysis | `.map.rpt` | No syntax errors, correct module hierarchy |
| Synthesis | `.syn.rpt` | Resource usage within budget, no inferred latches |
| Fitter | `.fit.rpt` | Successful placement, routing congestion acceptable |
| Timing Analysis | `.sta.rpt` | All clocks meet frequency targets, no setup/hold violations |
| Assembler | `.sof`, `.pof` | Bitstream generated successfully |
| Simulation | Transcript log | All test cases pass, no assertion failures |

---

## 4. Regression Testing Fundamentals

### Types of Regression Tests

#### 1. Smoke Test (Quick Sanity)
Runs synthesis only on the top-level module to verify the design compiles.
Typical runtime: 2-5 minutes.

#### 2. Full Compilation Regression
Runs the complete flow (synthesis → fitter → timing → assembler) on all
configurations. Typical runtime: 30-120 minutes.

#### 3. Simulation Regression
Runs all testbenches through ModelSim/Questa and checks for pass/fail.
Typical runtime: 10-60 minutes depending on test count.

#### 4. Multi-Device Regression
Compiles the design targeting multiple FPGA devices (e.g., Cyclone V,
Cyclone 10 LP, MAX 10) to verify portability. Typical runtime: scales
linearly with device count.

#### 5. Multi-Configuration Regression
Tests different parameter combinations (bus widths, FIFO depths, feature
enables) to verify configurability. Typical runtime: scales with
configuration count.

### Test Result Classification

```
┌──────────────────────────────────────────────────────┐
│                   Test Outcome                       │
├───────────┬───────────┬──────────┬───────────────────┤
│   PASS    │   FAIL    │  WARN    │     TIMEOUT       │
│           │           │          │                   │
│ All checks│ Hard error│ Timing   │ Build exceeded    │
│ passed    │ in any    │ margin   │ time limit        │
│           │ stage     │ < 10%    │                   │
└───────────┴───────────┴──────────┴───────────────────┘
```

---

## 5. Project Structure and Organization

This tutorial uses the following directory layout:

```
altera-fpga-regression/
├── README.md                  # This tutorial
├── Makefile                   # Top-level regression Makefile
├── examples/
│   ├── rtl/                   # Synthesizable RTL designs
│   │   ├── counter.sv         # Parameterized counter
│   │   ├── fifo_sync.sv       # Synchronous FIFO
│   │   ├── alu.sv             # Simple ALU
│   │   └── top_wrapper.sv     # Top-level wrapper
│   ├── testbench/             # Self-checking testbenches
│   │   ├── tb_counter.sv      # Counter testbench
│   │   ├── tb_fifo_sync.sv    # FIFO testbench
│   │   ├── tb_alu.sv          # ALU testbench
│   │   └── tb_pkg.sv          # Shared testbench utilities
│   ├── tcl/                   # Quartus automation scripts
│   │   ├── create_project.tcl # Project creation
│   │   ├── compile_design.tcl # Full compilation
│   │   ├── check_timing.tcl   # Timing analysis
│   │   ├── run_regression.tcl # Regression orchestrator
│   │   └── device_map.tcl     # Device configuration
│   ├── scripts/               # Shell & Python automation
│   │   ├── run_regression.sh  # Main regression driver
│   │   ├── run_simulation.sh  # Simulation runner
│   │   ├── parse_results.py   # Result parser
│   │   ├── gen_report.py      # HTML report generator
│   │   └── trend_analysis.py  # Historical trend analysis
│   ├── constraints/           # Timing constraints
│   │   ├── clocks.sdc         # Clock definitions
│   │   ├── io_timing.sdc      # I/O timing constraints
│   │   └── exceptions.sdc     # False paths, multicycles
│   ├── config/                # Regression configuration
│   │   ├── regression.yaml    # Test suite definitions
│   │   ├── devices.yaml       # Target device list
│   │   └── thresholds.yaml    # Pass/fail thresholds
│   ├── ci/                    # CI/CD pipeline definitions
│   │   ├── github_actions.yml # GitHub Actions workflow
│   │   └── Jenkinsfile        # Jenkins pipeline
│   └── reports/               # Generated reports (gitignored)
│       └── .gitkeep
```

---

## 6. RTL Design Examples

The tutorial includes three parameterized designs that serve as regression targets.
Each design is intentionally small but exercises different aspects of the FPGA flow.

### 6.1 Parameterized Counter (`examples/rtl/counter.sv`)

A configurable up/down counter with enable, load, and overflow detection.
This design exercises basic sequential logic, parameterization, and clock enables.

```systemverilog
// See examples/rtl/counter.sv for the full source
module counter #(
    parameter int WIDTH = 8,
    parameter bit SATURATE = 1'b0
)(
    input  logic             clk,
    input  logic             rst_n,
    input  logic             enable,
    input  logic             load,
    input  logic             up_down,   // 1=up, 0=down
    input  logic [WIDTH-1:0] load_val,
    output logic [WIDTH-1:0] count,
    output logic             overflow,
    output logic             underflow
);
```

**Regression value:** Tests parameterization across different widths (8, 16, 32 bits),
saturation vs. wrap-around behavior, and clock enable inference.

### 6.2 Synchronous FIFO (`examples/rtl/fifo_sync.sv`)

A parameterized synchronous FIFO with configurable depth and width.
Exercises block RAM inference, pointer logic, and status flags.

```systemverilog
// See examples/rtl/fifo_sync.sv for the full source
module fifo_sync #(
    parameter int DATA_WIDTH = 8,
    parameter int DEPTH      = 16,
    parameter int ALMOST_FULL_THRESH  = DEPTH - 2,
    parameter int ALMOST_EMPTY_THRESH = 2
)(
    input  logic                  clk,
    input  logic                  rst_n,
    input  logic                  wr_en,
    input  logic                  rd_en,
    input  logic [DATA_WIDTH-1:0] wr_data,
    output logic [DATA_WIDTH-1:0] rd_data,
    output logic                  full,
    output logic                  empty,
    output logic                  almost_full,
    output logic                  almost_empty,
    output logic [$clog2(DEPTH):0] count
);
```

**Regression value:** Tests RAM inference (should map to M10K/M20K blocks), FIFO
pointer arithmetic, and parameterized threshold logic.

### 6.3 Simple ALU (`examples/rtl/alu.sv`)

A parameterized ALU supporting arithmetic and logical operations.
Exercises combinational logic optimization and carry-chain utilization.

```systemverilog
// See examples/rtl/alu.sv for the full source
module alu #(
    parameter int WIDTH = 16
)(
    input  logic [WIDTH-1:0] operand_a,
    input  logic [WIDTH-1:0] operand_b,
    input  logic [3:0]       operation,
    output logic [WIDTH-1:0] result,
    output logic             zero_flag,
    output logic             carry_flag,
    output logic             overflow_flag
);
```

**Regression value:** Tests DSP block inference for multiplication, carry chain
optimization, and combinational path depth.

### 6.4 Top-Level Wrapper (`examples/rtl/top_wrapper.sv`)

Instantiates all three sub-modules and adds I/O registers for timing closure.

---

## 7. Testbench Development

### 7.1 Testbench Utilities Package

The shared package (`examples/testbench/tb_pkg.sv`) provides common utilities:

```systemverilog
// Standardized pass/fail reporting
// Clock generation tasks
// Reset sequencing
// Timeout watchdog
// Result summary with exit codes
```

**Key principle:** Every testbench must produce a machine-parseable pass/fail
indication. The convention used here is:

```
** TEST PASSED **    → exit code 0
** TEST FAILED **    → exit code 1
```

This enables automated result collection by the regression scripts.

### 7.2 Self-Checking Testbench Pattern

All testbenches in this tutorial follow this pattern:

```systemverilog
module tb_example;
    // 1. Signal declarations and DUT instantiation
    // 2. Clock generation
    // 3. Task-based stimulus
    // 4. Scoreboard / checker
    // 5. Test sequencer with error counting
    // 6. Final pass/fail reporting

    int error_count = 0;
    int test_count  = 0;

    // ... stimulus and checking ...

    final begin
        $display("==============================================");
        $display("  Tests run: %0d  |  Errors: %0d", test_count, error_count);
        if (error_count == 0)
            $display("  ** TEST PASSED **");
        else
            $display("  ** TEST FAILED **");
        $display("==============================================");
    end
endmodule
```

### 7.3 Counter Testbench Details

The counter testbench (`examples/testbench/tb_counter.sv`) covers:

1. **Reset behavior** — counter initializes to zero
2. **Count up** — increments on each enabled clock
3. **Count down** — decrements on each enabled clock
4. **Load** — parallel load overrides counting
5. **Overflow/underflow** — flags assert at boundaries
6. **Saturation mode** — counter clamps instead of wrapping
7. **Enable gating** — counter holds when disabled

### 7.4 FIFO Testbench Details

The FIFO testbench (`examples/testbench/tb_fifo_sync.sv`) covers:

1. **Write until full** — verifies full flag assertion
2. **Read until empty** — verifies empty flag assertion
3. **Simultaneous read/write** — steady-state throughput
4. **Almost-full/almost-empty** — threshold flag timing
5. **Data integrity** — written data matches read data (FIFO ordering)
6. **Overflow protection** — writes ignored when full
7. **Underflow protection** — reads return nothing when empty

### 7.5 ALU Testbench Details

The ALU testbench (`examples/testbench/tb_alu.sv`) covers:

1. **Arithmetic operations** — add, subtract, multiply, divide
2. **Logical operations** — AND, OR, XOR, NOT
3. **Shift operations** — left shift, right shift, arithmetic right shift
4. **Flag generation** — zero, carry, overflow flags
5. **Boundary values** — max, min, zero operands
6. **Random stimulus** — constrained random operand pairs

---

## 8. Tcl-Based Quartus Automation

Quartus Prime is fully scriptable through Tcl. The `quartus_sh` command-line
tool sources Tcl scripts to perform every operation available in the GUI.

### 8.1 Project Creation (`examples/tcl/create_project.tcl`)

This script creates a Quartus project from scratch, setting the device,
adding source files, and applying initial settings:

```tcl
# Usage: quartus_sh -t create_project.tcl <project_name> <device> <top_module>
# See examples/tcl/create_project.tcl for full source
```

Key operations:
- `project_new` — creates the `.qpf` and `.qsf` files
- `set_global_assignment` — configures device, top-level, source files
- `set_instance_assignment` — applies instance-specific settings

### 8.2 Full Compilation (`examples/tcl/compile_design.tcl`)

Runs the complete synthesis → fitter → timing → assembler flow:

```tcl
# Usage: quartus_sh -t compile_design.tcl <project_name> [revision]
```

The script:
1. Opens the project
2. Runs `quartus_map` (Analysis & Synthesis)
3. Runs `quartus_fit` (Fitter)
4. Runs `quartus_sta` (Timing Analysis)
5. Runs `quartus_asm` (Assembler)
6. Collects resource usage and timing summaries
7. Returns a non-zero exit code on any failure

### 8.3 Timing Analysis (`examples/tcl/check_timing.tcl`)

Performs detailed timing checks and extracts worst-case slack:

```tcl
# Usage: quartus_sta -t check_timing.tcl <project_name>
```

This script:
1. Creates a timing netlist
2. Reads the SDC constraints
3. Reports setup and hold slack for all clocks
4. Checks for unconstrained paths
5. Exports results in machine-readable format

### 8.4 Regression Orchestrator (`examples/tcl/run_regression.tcl`)

Ties together project creation, compilation, and timing analysis for
multiple configurations:

```tcl
# Usage: quartus_sh -t run_regression.tcl <config_file>
```

Features:
- Reads a configuration file defining test cases
- Iterates over device/parameter combinations
- Captures per-test pass/fail status
- Generates a summary table

### 8.5 Device Configuration Map (`examples/tcl/device_map.tcl`)

Maps logical device names to Quartus part numbers:

```tcl
# Cyclone V family
dict set device_map "cyclone_v_small"  "5CEBA2F17A7"
dict set device_map "cyclone_v_medium" "5CEBA4F23C7"
dict set device_map "cyclone_v_large"  "5CEBA9F31C6"

# Cyclone 10 LP family
dict set device_map "cyclone10_small"  "10CL006YE144C8G"
dict set device_map "cyclone10_large"  "10CL120YF780I7G"

# MAX 10 family
dict set device_map "max10_small"      "10M02SCE144I7G"
dict set device_map "max10_large"      "10M50DAF484C6GES"
```

---

## 9. Shell Script Orchestration

### 9.1 Main Regression Driver (`examples/scripts/run_regression.sh`)

The top-level shell script that:
1. Parses command-line arguments (test suite, devices, parallelism)
2. Sets up the build environment
3. Launches Quartus compilation jobs (optionally in parallel)
4. Collects results from each job
5. Invokes the Python report generator
6. Returns a non-zero exit code if any test failed

```bash
# Usage examples:
./examples/scripts/run_regression.sh --suite smoke
./examples/scripts/run_regression.sh --suite full --device cyclone_v --jobs 4
./examples/scripts/run_regression.sh --suite all --report html
```

Key features:
- **Parallel execution** via `GNU parallel` or background jobs with `wait`
- **Timeout enforcement** to prevent runaway builds
- **Log capture** with timestamps for post-mortem analysis
- **Email/Slack notification** on failure (configurable)

### 9.2 Simulation Runner (`examples/scripts/run_simulation.sh`)

Automates ModelSim/Questa for batch simulation:

```bash
# Usage:
./examples/scripts/run_simulation.sh --test tb_counter
./examples/scripts/run_simulation.sh --all
```

The script:
1. Compiles all RTL and testbench files with `vlog`
2. Optimizes with `vopt` (optional)
3. Runs simulation with `vsim -batch`
4. Searches the transcript for `** TEST PASSED **` or `** TEST FAILED **`
5. Reports results and returns appropriate exit codes

---

## 10. Makefile-Based Regression Flow

The `Makefile` provides a familiar interface for all regression operations.

### Key Targets

```makefile
make help          # Show available targets
make smoke         # Quick synthesis-only check
make compile       # Full compilation (single device)
make sim           # Run all simulations
make regress       # Full regression (compile + sim, all devices)
make report        # Generate HTML report from last run
make clean         # Remove all build artifacts
make trend         # Generate trend analysis from historical data
```

### Usage Examples

```bash
# Smoke test on default device
make smoke

# Full compile on a specific device
make compile DEVICE=cyclone_v_medium

# Run simulation for a specific testbench
make sim TB=tb_fifo_sync

# Full regression with 4 parallel jobs
make regress JOBS=4

# Full regression on all devices
make regress DEVICE=all JOBS=8

# Parameterized regression (sweep counter width)
make regress PARAMS="WIDTH=8 WIDTH=16 WIDTH=32"
```

### Makefile Structure

The Makefile is organized into sections:

1. **Configuration** — default variables, device lists, paths
2. **Synthesis targets** — map, syn, fit, sta, asm
3. **Simulation targets** — compile TB, run TB, check results
4. **Regression targets** — iterate over configurations
5. **Reporting targets** — invoke Python report generators
6. **Utility targets** — clean, help, status

---

## 11. Python-Based Result Parsing and Reporting

### 11.1 Result Parser (`examples/scripts/parse_results.py`)

Parses Quartus report files (`.rpt`) and extracts key metrics:

```python
# Extracted metrics:
# - Resource usage (ALMs, registers, memory bits, DSP blocks)
# - Timing (worst-case setup slack, hold slack, Fmax)
# - Compilation time per stage
# - Warning and error counts
```

The parser handles multiple report formats across Quartus versions and
outputs structured data (JSON) for downstream processing.

### 11.2 HTML Report Generator (`examples/scripts/gen_report.py`)

Generates a self-contained HTML report with:

- **Summary dashboard** — overall pass/fail, total tests, duration
- **Per-test detail table** — status, device, timing, resources
- **Resource utilization charts** — bar charts showing ALM/register usage
- **Timing summary** — clock-by-clock Fmax and slack
- **Build log links** — clickable links to raw log files
- **Color coding** — green for pass, red for fail, yellow for warning

### 11.3 Trend Analysis (`examples/scripts/trend_analysis.py`)

Tracks metrics over time by comparing results across regression runs:

- **Fmax trend** — is timing getting better or worse?
- **Resource trend** — is the design growing?
- **Warning count trend** — are new warnings appearing?
- **Compilation time trend** — are builds getting slower?

---

## 12. Timing Constraint Management

### 12.1 Clock Definitions (`examples/constraints/clocks.sdc`)

```sdc
# Primary clock at 100 MHz
create_clock -name sys_clk -period 10.000 [get_ports clk]

# Derived clocks (PLL outputs)
# create_generated_clock -name pll_clk_2x -source [get_ports clk] \
#     -multiply_by 2 [get_pins pll_inst|outclk_0]
```

### 12.2 I/O Timing (`examples/constraints/io_timing.sdc`)

```sdc
# Input delay (data arrives 2ns after clock edge)
set_input_delay -clock sys_clk -max 2.000 [get_ports {data_in[*]}]
set_input_delay -clock sys_clk -min 0.500 [get_ports {data_in[*]}]

# Output delay (data must be stable 3ns before next clock edge)
set_output_delay -clock sys_clk -max 3.000 [get_ports {data_out[*]}]
set_output_delay -clock sys_clk -min 0.500 [get_ports {data_out[*]}]
```

### 12.3 Timing Exceptions (`examples/constraints/exceptions.sdc`)

```sdc
# False path: reset is asynchronous
set_false_path -from [get_ports rst_n]

# Multicycle path: enable is sampled every 2 clocks
# set_multicycle_path 2 -setup -from [get_registers {*enable_sync*}]
# set_multicycle_path 1 -hold  -from [get_registers {*enable_sync*}]
```

### Regression Testing Constraints

When constraints change, regression testing should verify:

1. **No new unconstrained paths** — all clocks and I/Os are constrained
2. **Slack margins** — timing should not degrade beyond a threshold
3. **Clock domain crossings** — CDC paths are properly constrained
4. **Constraint coverage** — percentage of paths that are constrained

---

## 13. CI/CD Integration

### 13.1 GitHub Actions (`examples/ci/github_actions.yml`)

The GitHub Actions workflow:
1. Triggers on push to `main` or any pull request
2. Sets up a self-hosted runner with Quartus installed
3. Runs the smoke test suite on every PR
4. Runs the full regression nightly
5. Posts results as a PR comment
6. Archives build artifacts and reports

```yaml
# See examples/ci/github_actions.yml for the full workflow
# Key stages: checkout → setup → smoke/full regression → report → archive
```

### 13.2 Jenkins Pipeline (`examples/ci/Jenkinsfile`)

The Jenkins pipeline:
1. Uses a declarative pipeline with stages
2. Supports parameterized builds (device, suite, parallelism)
3. Runs on agents with Quartus pre-installed
4. Publishes HTML reports as build artifacts
5. Sends email notifications on failure
6. Tracks timing trends across builds

### Self-Hosted Runner Requirements

Since Quartus is a commercial tool that requires a license, CI/CD
runners must be self-hosted machines with:

- Quartus Prime installed and licensed
- Sufficient RAM (16 GB+ recommended)
- Fast storage (SSD recommended for compilation speed)
- Network access to the license server

---

## 14. Advanced Regression Strategies

### 14.1 Incremental Compilation

Quartus supports incremental compilation where only changed partitions
are re-synthesized and re-fitted. This can dramatically reduce regression
time for large designs:

```tcl
# Enable incremental compilation
set_global_assignment -name INCREMENTAL_COMPILATION FULL_INCREMENTAL_COMPILATION

# Define partitions
set_instance_assignment -name PARTITION_HIERARCHY root_partition -to | -section_id Top
```

**Regression consideration:** Run full compilation periodically (nightly)
to verify incremental results match full results.

### 14.2 Seed Sweeping

The Quartus fitter uses a random seed that affects placement. Seed sweeping
runs the fitter multiple times with different seeds to find the best
timing result:

```bash
# Run fitter with seeds 1-5
for seed in 1 2 3 4 5; do
    quartus_fit --seed=$seed project_name
    quartus_sta project_name
done
```

**Regression consideration:** Track the best seed for each configuration
and alert when the best-seed Fmax drops.

### 14.3 Design Space Exploration

Automatically sweep Quartus settings to find optimal configurations:

```tcl
# Optimization modes to test
set opt_modes {
    "BALANCED"
    "HIGH_PERFORMANCE_EFFORT"
    "AGGRESSIVE_AREA"
    "AGGRESSIVE_PERFORMANCE"
}

foreach mode $opt_modes {
    set_global_assignment -name OPTIMIZATION_MODE $mode
    # ... run compilation and record results ...
}
```

### 14.4 Gate-Level Simulation

After place-and-route, run gate-level simulation with timing annotations
to verify functional correctness with real delays:

```bash
# Generate gate-level netlist
quartus_eda --simulation --tool=modelsim --format=systemverilog project_name

# Run gate-level simulation with SDF annotation
vsim -sdftyp /tb/dut=project_name.sdo work.tb_top
```

### 14.5 Resource Budget Enforcement

Set resource budgets and fail the regression if they are exceeded:

```yaml
# In config/thresholds.yaml
resource_budgets:
  alm_usage_percent: 80      # Fail if ALM usage exceeds 80%
  register_count_max: 50000   # Fail if register count exceeds 50k
  memory_bits_max: 500000     # Fail if memory usage exceeds 500kbits
  dsp_blocks_max: 20          # Fail if DSP block count exceeds 20
```

---

## 15. Debugging and Troubleshooting

### Common Regression Failures

#### Synthesis Failures

| Symptom | Likely Cause | Resolution |
|---|---|---|
| `Error: Can't find module` | Missing source file | Check file list in `.qsf` |
| `Error: Inferred latch` | Incomplete case/if | Add default assignments |
| `Error: Multi-driven net` | Multiple drivers | Review signal assignments |
| `Critical Warning: Combinational loop` | Feedback path | Break loop with register |

#### Timing Failures

| Symptom | Likely Cause | Resolution |
|---|---|---|
| Negative setup slack | Long combinational path | Pipeline the logic |
| Negative hold slack | Short path with clock skew | Add delay or use PLL |
| Unconstrained paths | Missing SDC constraints | Update SDC file |
| Clock domain crossing | Missing CDC constraints | Add proper synchronizers |

#### Fitter Failures

| Symptom | Likely Cause | Resolution |
|---|---|---|
| `Error: Can't place all nodes` | Device too small | Use larger device or reduce design |
| `Error: Routing congestion` | High utilization | Optimize design or use larger device |
| `Error: Pin assignment conflict` | Conflicting pin assignments | Review pin planner |

### Debugging Tips

1. **Always check the `.map.rpt` first** — synthesis warnings often predict downstream failures
2. **Use `--rev` to maintain multiple revisions** — compare passing vs. failing builds
3. **Enable `quartus_sta` verbose mode** — shows detailed path analysis
4. **Check the fitter messages for "retime" suggestions** — the fitter often suggests fixes
5. **Use SignalTap for in-hardware debugging** — add a regression test that verifies SignalTap builds

---

## 16. Best Practices

### Project Organization

1. **Version control everything** — RTL, constraints, scripts, Quartus settings (`.qsf`)
2. **Never version-control generated files** — `.db`, `.sof`, `.rpt` belong in `.gitignore`
3. **Use a flat source directory** — avoids path issues across platforms
4. **Pin your tool versions** — document the exact Quartus version in the regression config

### Script Design

1. **Idempotent builds** — running the same script twice produces the same result
2. **Non-zero exit codes** — every script must exit non-zero on failure
3. **Timestamped logs** — every log entry includes a timestamp
4. **Artifact archival** — compress and archive build results for trend analysis

### Timing Closure

1. **Constrain first, synthesize second** — never run synthesis without SDC
2. **Over-constrain by 10%** — gives margin for silicon variation
3. **Track Fmax trends** — plot Fmax over time to catch slow degradation
4. **Review unconstrained path reports** — should always be zero

### Regression Maintenance

1. **Keep smoke tests under 5 minutes** — developers should run them before every commit
2. **Run full regression nightly** — catches issues that smoke tests miss
3. **Review warnings weekly** — new warnings often predict future failures
4. **Automate everything** — if you do it manually more than twice, script it

### Team Workflow

1. **PR-gated smoke tests** — no merge without passing smoke test
2. **Nightly full regression emails** — the whole team sees the status
3. **Regression ownership** — assign an owner to fix failures within 24 hours
4. **Regression review meetings** — weekly review of trends and failures

---

## Quick Start

To get started with the examples in this tutorial:

```bash
# 1. Clone this repository
git clone <repo_url>
cd altera-fpga-regression

# 2. Set up your environment (edit paths for your installation)
export QUARTUS_ROOTDIR="/opt/intelFPGA/23.1/quartus"
export PATH="${QUARTUS_ROOTDIR}/bin:${PATH}"

# 3. Run the smoke test (synthesis only)
make smoke

# 4. Run a simulation
make sim TB=tb_counter

# 5. Run full regression
make regress

# 6. View the report
open examples/reports/regression_report.html
```

---

## Further Reading

- [Intel Quartus Prime Scripting Reference](https://www.intel.com/content/www/us/en/docs/programmable/683432/)
- [Intel Quartus Prime Handbook](https://www.intel.com/content/www/us/en/docs/programmable/683283/)
- [Intel FPGA Technical Documentation](https://www.intel.com/content/www/us/en/programmable/documentation/)
- [SystemVerilog IEEE 1800-2017 Standard](https://standards.ieee.org/standard/1800-2017.html)
- [SDC (Synopsys Design Constraints) Reference](https://www.intel.com/content/www/us/en/docs/programmable/683283/)
- [ModelSim User's Guide](https://www.intel.com/content/www/us/en/docs/programmable/683247/)

---

*This tutorial is part of the FPGA automation knowledge base. All example files
are located in the `examples/` directory and are ready to be adapted for your
own projects.*
