#!/usr/bin/env bash
# =============================================================================
# run_regression.sh — Main regression driver for Altera FPGA designs
# =============================================================================
# Usage:
#   ./run_regression.sh [OPTIONS]
#
# Options:
#   --suite <name>      Test suite: smoke|compile|sim|full|all (default: smoke)
#   --device <name>     Target device: cyclone_v|cyclone10|max10|all (default: cyclone_v)
#   --jobs <n>          Parallel compilation jobs (default: 1)
#   --timeout <sec>     Per-build timeout in seconds (default: 3600)
#   --report <format>   Report format: text|html|json (default: text)
#   --notify            Send email/Slack notification on failure
#   --help              Show this help message
#
# Examples:
#   ./run_regression.sh --suite smoke
#   ./run_regression.sh --suite full --device cyclone_v --jobs 4
#   ./run_regression.sh --suite all --report html --notify
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration defaults
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
RTL_DIR="${PROJECT_ROOT}/examples/rtl"
TB_DIR="${PROJECT_ROOT}/examples/testbench"
TCL_DIR="${PROJECT_ROOT}/examples/tcl"
CONSTRAINT_DIR="${PROJECT_ROOT}/examples/constraints"
REPORT_DIR="${PROJECT_ROOT}/examples/reports"
CONFIG_DIR="${PROJECT_ROOT}/examples/config"

SUITE="smoke"
DEVICE="cyclone_v"
JOBS=1
TIMEOUT=3600
REPORT_FORMAT="text"
NOTIFY=false
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BUILD_DIR="${PROJECT_ROOT}/build_${TIMESTAMP}"

# Device to part number mapping
declare -A DEVICE_MAP=(
    ["cyclone_v"]="5CEBA4F23C7"
    ["cyclone_v_small"]="5CEBA2F17A7"
    ["cyclone_v_large"]="5CEBA9F31C6"
    ["cyclone10"]="10CL025YU256I7G"
    ["cyclone10_small"]="10CL006YE144C8G"
    ["max10"]="10M16SAE144I7G"
    ["max10_small"]="10M02SCE144I7G"
    ["max10_large"]="10M50DAF484C6GES"
)

# Device to family mapping
declare -A FAMILY_MAP=(
    ["cyclone_v"]="Cyclone V"
    ["cyclone_v_small"]="Cyclone V"
    ["cyclone_v_large"]="Cyclone V"
    ["cyclone10"]="Cyclone 10 LP"
    ["cyclone10_small"]="Cyclone 10 LP"
    ["max10"]="MAX 10"
    ["max10_small"]="MAX 10"
    ["max10_large"]="MAX 10"
)

# Counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
SKIPPED_TESTS=0

# Results array (for report generation)
RESULTS_FILE=""

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
log_info()  { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO]  $*"; }
log_warn()  { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WARN]  $*" >&2; }
log_error() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $*" >&2; }

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
show_help() {
    head -n 16 "$0" | tail -n 14
    exit 0
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --suite)   SUITE="$2"; shift 2 ;;
            --device)  DEVICE="$2"; shift 2 ;;
            --jobs)    JOBS="$2"; shift 2 ;;
            --timeout) TIMEOUT="$2"; shift 2 ;;
            --report)  REPORT_FORMAT="$2"; shift 2 ;;
            --notify)  NOTIFY=true; shift ;;
            --help)    show_help ;;
            *)         log_error "Unknown option: $1"; show_help ;;
        esac
    done
}

# ---------------------------------------------------------------------------
# Environment check
# ---------------------------------------------------------------------------
check_environment() {
    log_info "Checking environment..."

    if ! command -v quartus_sh &>/dev/null; then
        log_error "quartus_sh not found. Set QUARTUS_ROOTDIR and update PATH."
        exit 1
    fi
    log_info "  Quartus: $(quartus_sh --version 2>/dev/null | head -1)"

    if [[ "${SUITE}" == "sim" || "${SUITE}" == "full" || "${SUITE}" == "all" ]]; then
        if ! command -v vsim &>/dev/null; then
            log_warn "vsim not found. Simulation tests will be skipped."
        else
            log_info "  ModelSim: $(vsim -version 2>/dev/null | head -1)"
        fi
    fi

    if ! command -v python3 &>/dev/null; then
        log_warn "python3 not found. Report generation may be limited."
    fi
}

# ---------------------------------------------------------------------------
# Build directory setup
# ---------------------------------------------------------------------------
setup_build_dir() {
    log_info "Creating build directory: ${BUILD_DIR}"
    mkdir -p "${BUILD_DIR}"
    RESULTS_FILE="${BUILD_DIR}/results.json"
    echo '{"tests": []}' > "${RESULTS_FILE}"
}

# ---------------------------------------------------------------------------
# Get the list of devices to test
# ---------------------------------------------------------------------------
get_device_list() {
    if [[ "${DEVICE}" == "all" ]]; then
        echo "${!DEVICE_MAP[@]}"
    else
        echo "${DEVICE}"
    fi
}

# ---------------------------------------------------------------------------
# Run a single compilation test
# ---------------------------------------------------------------------------
run_compile_test() {
    local test_name="$1"
    local device_name="$2"
    local device_part="${DEVICE_MAP[$device_name]}"
    local build_subdir="${BUILD_DIR}/${test_name}_${device_name}"

    log_info "Running compile test: ${test_name} on ${device_name} (${device_part})"

    mkdir -p "${build_subdir}"
    local log_file="${build_subdir}/compile.log"
    local start_time
    start_time=$(date +%s)
    local status="PASS"

    # Run compilation with timeout
    if timeout "${TIMEOUT}" quartus_sh -t "${TCL_DIR}/compile_design.tcl" \
        "${test_name}" > "${log_file}" 2>&1; then
        status="PASS"
    else
        local exit_code=$?
        if [[ ${exit_code} -eq 124 ]]; then
            status="TIMEOUT"
        else
            status="FAIL"
        fi
    fi

    local end_time
    end_time=$(date +%s)
    local elapsed=$((end_time - start_time))

    # Record result
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    case "${status}" in
        PASS)    PASSED_TESTS=$((PASSED_TESTS + 1)) ;;
        FAIL)    FAILED_TESTS=$((FAILED_TESTS + 1)) ;;
        TIMEOUT) FAILED_TESTS=$((FAILED_TESTS + 1)) ;;
    esac

    log_info "  Result: ${status} (${elapsed}s)"
    echo "${test_name},${device_name},${device_part},compile,${status},${elapsed}" \
        >> "${BUILD_DIR}/results.csv"
}

# ---------------------------------------------------------------------------
# Run a single simulation test
# ---------------------------------------------------------------------------
run_sim_test() {
    local tb_name="$1"
    local sim_dir="${BUILD_DIR}/sim_${tb_name}"

    log_info "Running simulation: ${tb_name}"

    mkdir -p "${sim_dir}"
    local log_file="${sim_dir}/sim.log"
    local start_time
    start_time=$(date +%s)
    local status="PASS"

    if ! command -v vsim &>/dev/null; then
        log_warn "  Skipping ${tb_name}: vsim not found"
        SKIPPED_TESTS=$((SKIPPED_TESTS + 1))
        return
    fi

    # Compile and simulate
    if timeout "${TIMEOUT}" bash "${SCRIPT_DIR}/run_simulation.sh" \
        --test "${tb_name}" --workdir "${sim_dir}" > "${log_file}" 2>&1; then
        # Check for PASS/FAIL in the log
        if grep -q "\\*\\* TEST PASSED \\*\\*" "${log_file}"; then
            status="PASS"
        elif grep -q "\\*\\* TEST FAILED \\*\\*" "${log_file}"; then
            status="FAIL"
        else
            status="FAIL"
        fi
    else
        local exit_code=$?
        if [[ ${exit_code} -eq 124 ]]; then
            status="TIMEOUT"
        else
            status="FAIL"
        fi
    fi

    local end_time
    end_time=$(date +%s)
    local elapsed=$((end_time - start_time))

    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    case "${status}" in
        PASS)    PASSED_TESTS=$((PASSED_TESTS + 1)) ;;
        FAIL)    FAILED_TESTS=$((FAILED_TESTS + 1)) ;;
        TIMEOUT) FAILED_TESTS=$((FAILED_TESTS + 1)) ;;
    esac

    log_info "  Result: ${status} (${elapsed}s)"
    echo "${tb_name},,sim,${status},${elapsed}" >> "${BUILD_DIR}/results.csv"
}

# ---------------------------------------------------------------------------
# Run smoke test suite (synthesis only)
# ---------------------------------------------------------------------------
run_smoke() {
    log_info "=== Running Smoke Test Suite ==="
    for dev in $(get_device_list); do
        run_compile_test "smoke" "${dev}"
    done
}

# ---------------------------------------------------------------------------
# Run full compilation suite
# ---------------------------------------------------------------------------
run_compile() {
    log_info "=== Running Full Compilation Suite ==="
    for dev in $(get_device_list); do
        run_compile_test "full_compile" "${dev}"
    done
}

# ---------------------------------------------------------------------------
# Run simulation suite
# ---------------------------------------------------------------------------
run_sim() {
    log_info "=== Running Simulation Suite ==="
    local testbenches=("tb_counter" "tb_fifo_sync" "tb_alu")
    for tb in "${testbenches[@]}"; do
        run_sim_test "${tb}"
    done
}

# ---------------------------------------------------------------------------
# Generate report
# ---------------------------------------------------------------------------
generate_report() {
    log_info "Generating ${REPORT_FORMAT} report..."

    local csv_file="${BUILD_DIR}/results.csv"
    local report_file

    case "${REPORT_FORMAT}" in
        html)
            report_file="${REPORT_DIR}/regression_report_${TIMESTAMP}.html"
            if command -v python3 &>/dev/null; then
                python3 "${SCRIPT_DIR}/gen_report.py" \
                    --input "${csv_file}" \
                    --output "${report_file}" \
                    --format html
                log_info "HTML report: ${report_file}"
            else
                log_warn "python3 not available; skipping HTML report."
            fi
            ;;
        json)
            report_file="${REPORT_DIR}/regression_report_${TIMESTAMP}.json"
            if command -v python3 &>/dev/null; then
                python3 "${SCRIPT_DIR}/gen_report.py" \
                    --input "${csv_file}" \
                    --output "${report_file}" \
                    --format json
                log_info "JSON report: ${report_file}"
            else
                log_warn "python3 not available; skipping JSON report."
            fi
            ;;
        text|*)
            report_file="${REPORT_DIR}/regression_report_${TIMESTAMP}.txt"
            {
                echo "================================================"
                echo "  Regression Report"
                echo "  Generated: $(date)"
                echo "  Suite: ${SUITE}"
                echo "================================================"
                echo ""
                echo "Results:"
                if [[ -f "${csv_file}" ]]; then
                    column -t -s',' "${csv_file}"
                fi
                echo ""
                echo "Summary:"
                echo "  Total:   ${TOTAL_TESTS}"
                echo "  Passed:  ${PASSED_TESTS}"
                echo "  Failed:  ${FAILED_TESTS}"
                echo "  Skipped: ${SKIPPED_TESTS}"
                echo ""
                if [[ ${FAILED_TESTS} -eq 0 ]]; then
                    echo "  ** REGRESSION PASSED **"
                else
                    echo "  ** REGRESSION FAILED **"
                fi
                echo "================================================"
            } > "${report_file}"
            log_info "Text report: ${report_file}"
            ;;
    esac
}

# ---------------------------------------------------------------------------
# Print summary
# ---------------------------------------------------------------------------
print_summary() {
    echo ""
    echo "============================================"
    echo "  Regression Summary"
    echo "  Suite  : ${SUITE}"
    echo "  Device : ${DEVICE}"
    echo "============================================"
    echo "  Total   : ${TOTAL_TESTS}"
    echo "  Passed  : ${PASSED_TESTS}"
    echo "  Failed  : ${FAILED_TESTS}"
    echo "  Skipped : ${SKIPPED_TESTS}"
    echo "--------------------------------------------"
    if [[ ${FAILED_TESTS} -eq 0 && ${TOTAL_TESTS} -gt 0 ]]; then
        echo "  ** REGRESSION PASSED **"
    elif [[ ${TOTAL_TESTS} -eq 0 ]]; then
        echo "  ** NO TESTS RUN **"
    else
        echo "  ** REGRESSION FAILED **"
    fi
    echo "============================================"
}

# ---------------------------------------------------------------------------
# Send notification (placeholder)
# ---------------------------------------------------------------------------
send_notification() {
    if [[ "${NOTIFY}" != "true" ]]; then
        return
    fi

    if [[ ${FAILED_TESTS} -gt 0 ]]; then
        log_info "Sending failure notification..."
        # Slack webhook (configure SLACK_WEBHOOK_URL in environment)
        if [[ -n "${SLACK_WEBHOOK_URL:-}" ]]; then
            curl -s -X POST "${SLACK_WEBHOOK_URL}" \
                -H 'Content-type: application/json' \
                -d "{\"text\":\"FPGA Regression FAILED: ${FAILED_TESTS}/${TOTAL_TESTS} tests failed (suite: ${SUITE})\"}" \
                || log_warn "Failed to send Slack notification"
        fi

        # Email (configure NOTIFY_EMAIL in environment)
        if [[ -n "${NOTIFY_EMAIL:-}" ]] && command -v mail &>/dev/null; then
            echo "FPGA Regression FAILED: ${FAILED_TESTS}/${TOTAL_TESTS} tests failed" | \
                mail -s "FPGA Regression Failure (${SUITE})" "${NOTIFY_EMAIL}" \
                || log_warn "Failed to send email notification"
        fi
    fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
    parse_args "$@"
    setup_build_dir

    # Initialize CSV header
    echo "test,device,part,type,status,elapsed_s" > "${BUILD_DIR}/results.csv"

    log_info "Starting regression: suite=${SUITE}, device=${DEVICE}, jobs=${JOBS}"

    case "${SUITE}" in
        smoke)   run_smoke ;;
        compile) run_compile ;;
        sim)     run_sim ;;
        full)    run_compile; run_sim ;;
        all)     run_smoke; run_compile; run_sim ;;
        *)       log_error "Unknown suite: ${SUITE}"; exit 1 ;;
    esac

    generate_report
    print_summary
    send_notification

    # Exit with failure if any tests failed
    if [[ ${FAILED_TESTS} -gt 0 ]]; then
        exit 1
    fi
    exit 0
}

main "$@"
