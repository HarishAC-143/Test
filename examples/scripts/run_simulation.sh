#!/usr/bin/env bash
# =============================================================================
# run_simulation.sh — Batch simulation runner for ModelSim/Questa
# =============================================================================
# Usage:
#   ./run_simulation.sh --test <testbench_name> [OPTIONS]
#   ./run_simulation.sh --all [OPTIONS]
#
# Options:
#   --test <name>       Run a specific testbench (e.g., tb_counter)
#   --all               Run all testbenches
#   --workdir <dir>     Working directory for simulation (default: ./sim_work)
#   --gui               Launch ModelSim GUI (default: batch mode)
#   --coverage          Enable code coverage collection
#   --seed <n>          Random seed for simulation (default: random)
#   --timeout <sec>     Simulation timeout in seconds (default: 600)
#   --verbose           Enable verbose output
#
# Examples:
#   ./run_simulation.sh --test tb_counter
#   ./run_simulation.sh --all --coverage
#   ./run_simulation.sh --test tb_alu --seed 42 --verbose
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
RTL_DIR="${PROJECT_ROOT}/examples/rtl"
TB_DIR="${PROJECT_ROOT}/examples/testbench"

# Defaults
TEST_NAME=""
RUN_ALL=false
WORK_DIR="./sim_work"
GUI_MODE=false
COVERAGE=false
SEED=""
TIMEOUT=600
VERBOSE=false

# All testbenches
ALL_TESTBENCHES=("tb_counter" "tb_fifo_sync" "tb_alu")

# Results
declare -A SIM_RESULTS

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
log_info()  { echo "[$(date '+%H:%M:%S')] [INFO]  $*"; }
log_error() { echo "[$(date '+%H:%M:%S')] [ERROR] $*" >&2; }

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --test)     TEST_NAME="$2"; shift 2 ;;
            --all)      RUN_ALL=true; shift ;;
            --workdir)  WORK_DIR="$2"; shift 2 ;;
            --gui)      GUI_MODE=true; shift ;;
            --coverage) COVERAGE=true; shift ;;
            --seed)     SEED="$2"; shift 2 ;;
            --timeout)  TIMEOUT="$2"; shift 2 ;;
            --verbose)  VERBOSE=true; shift ;;
            *)          log_error "Unknown option: $1"; exit 1 ;;
        esac
    done

    if [[ -z "${TEST_NAME}" && "${RUN_ALL}" != "true" ]]; then
        log_error "Specify --test <name> or --all"
        exit 1
    fi
}

# ---------------------------------------------------------------------------
# Compile RTL and testbench sources
# ---------------------------------------------------------------------------
compile_sources() {
    local work_lib="${WORK_DIR}/work"

    log_info "Compiling sources..."
    mkdir -p "${WORK_DIR}"

    # Create work library
    vlib "${work_lib}" 2>/dev/null || true
    vmap work "${work_lib}"

    # Compile shared package first
    log_info "  Compiling tb_pkg.sv"
    vlog -sv -work work "${TB_DIR}/tb_pkg.sv"

    # Compile RTL files
    for f in "${RTL_DIR}"/*.sv "${RTL_DIR}"/*.v; do
        [[ -f "$f" ]] || continue
        log_info "  Compiling $(basename "$f")"
        vlog -sv -work work "$f"
    done

    # Compile testbench files
    for f in "${TB_DIR}"/tb_*.sv; do
        [[ -f "$f" ]] || continue
        log_info "  Compiling $(basename "$f")"
        vlog -sv -work work "$f"
    done

    log_info "Compilation complete."
}

# ---------------------------------------------------------------------------
# Run a single simulation
# ---------------------------------------------------------------------------
run_single_sim() {
    local tb="$1"
    local transcript="${WORK_DIR}/${tb}_transcript.log"
    local vsim_args="-batch -do \"run -all; quit -f\" -logfile ${transcript}"

    log_info "Simulating: ${tb}"

    # Add optional arguments
    if [[ "${COVERAGE}" == "true" ]]; then
        vsim_args="-coverage ${vsim_args}"
    fi

    if [[ -n "${SEED}" ]]; then
        vsim_args="-sv_seed ${SEED} ${vsim_args}"
    fi

    if [[ "${GUI_MODE}" == "true" ]]; then
        vsim_args="-do \"run -all\" work.${tb}"
    fi

    local start_time
    start_time=$(date +%s)
    local status="UNKNOWN"

    # Run simulation
    if [[ "${GUI_MODE}" == "true" ]]; then
        vsim work."${tb}" &
        status="LAUNCHED"
    else
        if timeout "${TIMEOUT}" vsim -batch \
            -do "run -all; quit -f" \
            -logfile "${transcript}" \
            work."${tb}" > "${WORK_DIR}/${tb}_vsim.log" 2>&1; then

            # Check transcript for pass/fail
            if grep -q "\*\* TEST PASSED \*\*" "${transcript}" 2>/dev/null; then
                status="PASS"
            elif grep -q "\*\* TEST FAILED \*\*" "${transcript}" 2>/dev/null; then
                status="FAIL"
            else
                # Also check vsim output
                if grep -q "\*\* TEST PASSED \*\*" "${WORK_DIR}/${tb}_vsim.log" 2>/dev/null; then
                    status="PASS"
                else
                    status="FAIL"
                fi
            fi
        else
            local ec=$?
            if [[ ${ec} -eq 124 ]]; then
                status="TIMEOUT"
            else
                status="FAIL"
            fi
        fi
    fi

    local end_time
    end_time=$(date +%s)
    local elapsed=$((end_time - start_time))

    SIM_RESULTS["${tb}"]="${status}"
    log_info "  ${tb}: ${status} (${elapsed}s)"

    if [[ "${VERBOSE}" == "true" && -f "${transcript}" ]]; then
        log_info "  Transcript tail:"
        tail -20 "${transcript}" | sed 's/^/    /'
    fi
}

# ---------------------------------------------------------------------------
# Print simulation summary
# ---------------------------------------------------------------------------
print_sim_summary() {
    local total=0
    local passed=0
    local failed=0

    echo ""
    echo "============================================"
    echo "  Simulation Summary"
    echo "============================================"

    for tb in "${!SIM_RESULTS[@]}"; do
        local status="${SIM_RESULTS[$tb]}"
        printf "  %-25s : %s\n" "${tb}" "${status}"
        total=$((total + 1))
        [[ "${status}" == "PASS" ]] && passed=$((passed + 1))
        [[ "${status}" != "PASS" && "${status}" != "LAUNCHED" ]] && failed=$((failed + 1))
    done

    echo "--------------------------------------------"
    echo "  Total: ${total}  |  Passed: ${passed}  |  Failed: ${failed}"

    if [[ ${failed} -eq 0 && ${total} -gt 0 ]]; then
        echo ""
        echo "  ** TEST PASSED **"
    elif [[ ${failed} -gt 0 ]]; then
        echo ""
        echo "  ** TEST FAILED **"
    fi
    echo "============================================"

    return ${failed}
}

# ---------------------------------------------------------------------------
# Merge coverage data
# ---------------------------------------------------------------------------
merge_coverage() {
    if [[ "${COVERAGE}" != "true" ]]; then
        return
    fi

    log_info "Merging coverage data..."
    local ucdb_files=("${WORK_DIR}"/*.ucdb)
    if [[ ${#ucdb_files[@]} -gt 0 ]]; then
        vcover merge "${WORK_DIR}/merged_coverage.ucdb" "${ucdb_files[@]}" \
            > "${WORK_DIR}/coverage_merge.log" 2>&1 || true

        vcover report -html -output "${WORK_DIR}/coverage_html" \
            "${WORK_DIR}/merged_coverage.ucdb" \
            > "${WORK_DIR}/coverage_report.log" 2>&1 || true

        log_info "Coverage report: ${WORK_DIR}/coverage_html/index.html"
    fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
    parse_args "$@"

    log_info "=== Simulation Runner ==="

    # Compile all sources
    compile_sources

    # Run simulations
    if [[ "${RUN_ALL}" == "true" ]]; then
        for tb in "${ALL_TESTBENCHES[@]}"; do
            run_single_sim "${tb}"
        done
    else
        run_single_sim "${TEST_NAME}"
    fi

    # Coverage merge
    merge_coverage

    # Print summary and exit
    print_sim_summary
    exit $?
}

main "$@"
