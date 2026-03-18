# =============================================================================
# Makefile — Altera FPGA Regression Test Automation
# =============================================================================
# Top-level Makefile for building, simulating, and regression-testing
# Altera FPGA designs using Quartus Prime and ModelSim/Questa.
#
# Usage:
#   make help          - Show all available targets
#   make smoke         - Quick synthesis-only check
#   make compile       - Full compilation (single device)
#   make sim           - Run all simulations
#   make regress       - Full regression (compile + sim)
#   make report        - Generate HTML report
#   make clean         - Remove all build artifacts
# =============================================================================

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
PROJECT_NAME    ?= fpga_regression
TOP_MODULE      ?= top_wrapper
DEVICE          ?= cyclone_v
DEVICE_PART     ?= 5CEBA4F23C7
DEVICE_FAMILY   ?= "Cyclone V"

# Directories
RTL_DIR         := examples/rtl
TB_DIR          := examples/testbench
TCL_DIR         := examples/tcl
SCRIPT_DIR      := examples/scripts
CONSTRAINT_DIR  := examples/constraints
REPORT_DIR      := examples/reports
BUILD_DIR       := build

# Tools
QUARTUS_SH      ?= quartus_sh
QUARTUS_MAP     ?= quartus_map
QUARTUS_FIT     ?= quartus_fit
QUARTUS_STA     ?= quartus_sta
QUARTUS_ASM     ?= quartus_asm
VLIB            ?= vlib
VLOG            ?= vlog
VSIM            ?= vsim
PYTHON          ?= python3

# Options
JOBS            ?= 1
TIMEOUT         ?= 3600
TB              ?=
SEED            ?=
PARAMS          ?=
VERBOSE         ?=

# Timestamp
TIMESTAMP       := $(shell date +"%Y%m%d_%H%M%S")

# Source files
RTL_SOURCES     := $(wildcard $(RTL_DIR)/*.sv) $(wildcard $(RTL_DIR)/*.v)
TB_SOURCES      := $(wildcard $(TB_DIR)/*.sv)
SDC_FILES       := $(wildcard $(CONSTRAINT_DIR)/*.sdc)

# All testbenches (auto-discovered from tb_*.sv files)
ALL_TB          := $(basename $(notdir $(filter $(TB_DIR)/tb_%.sv, $(TB_SOURCES))))

# Device matrix for multi-device regression
DEVICE_LIST     ?= cyclone_v
ALL_DEVICES     := cyclone_v cyclone10 max10

# Per-device part numbers
PART_cyclone_v  := 5CEBA4F23C7
PART_cyclone10  := 10CL025YU256I7G
PART_max10      := 10M16SAE144I7G
FAMILY_cyclone_v  := "Cyclone V"
FAMILY_cyclone10  := "Cyclone 10 LP"
FAMILY_max10      := "MAX 10"

# ---------------------------------------------------------------------------
# Phony targets
# ---------------------------------------------------------------------------
.PHONY: help smoke compile sim regress report trend clean \
        setup check-tools sim-all sim-single \
        compile-single compile-all

# ---------------------------------------------------------------------------
# Default target
# ---------------------------------------------------------------------------
.DEFAULT_GOAL := help

# ---------------------------------------------------------------------------
# Help
# ---------------------------------------------------------------------------
help:
	@echo "================================================================"
	@echo "  Altera FPGA Regression Automation"
	@echo "================================================================"
	@echo ""
	@echo "Build Targets:"
	@echo "  make smoke               Quick synthesis-only check"
	@echo "  make compile             Full compilation (single device)"
	@echo "  make compile-all         Full compilation (all devices)"
	@echo ""
	@echo "Simulation Targets:"
	@echo "  make sim                 Run all simulations"
	@echo "  make sim TB=tb_counter   Run a specific testbench"
	@echo ""
	@echo "Regression Targets:"
	@echo "  make regress             Full regression (compile + sim)"
	@echo "  make regress DEVICE=all  Regression on all devices"
	@echo "  make regress JOBS=4      Parallel regression"
	@echo ""
	@echo "Report Targets:"
	@echo "  make report              Generate HTML report"
	@echo "  make trend               Generate trend analysis"
	@echo ""
	@echo "Utility Targets:"
	@echo "  make check-tools         Verify tool availability"
	@echo "  make clean               Remove all build artifacts"
	@echo "  make status              Show project status"
	@echo ""
	@echo "Variables:"
	@echo "  DEVICE=cyclone_v         Target device (default: cyclone_v)"
	@echo "  TB=tb_counter            Specific testbench to run"
	@echo "  JOBS=4                   Parallel jobs"
	@echo "  SEED=42                  Simulation random seed"
	@echo "  VERBOSE=1                Enable verbose output"
	@echo "================================================================"

# ---------------------------------------------------------------------------
# Tool check
# ---------------------------------------------------------------------------
check-tools:
	@echo "Checking tools..."
	@which $(QUARTUS_SH) > /dev/null 2>&1 && echo "  [OK] Quartus: $$($(QUARTUS_SH) --version 2>/dev/null | head -1)" || echo "  [MISSING] quartus_sh"
	@which $(VSIM) > /dev/null 2>&1 && echo "  [OK] ModelSim: $$($(VSIM) -version 2>/dev/null | head -1)" || echo "  [MISSING] vsim"
	@which $(PYTHON) > /dev/null 2>&1 && echo "  [OK] Python: $$($$(PYTHON) --version 2>&1)" || echo "  [MISSING] python3"
	@which make > /dev/null 2>&1 && echo "  [OK] Make: $$(make --version | head -1)" || echo "  [MISSING] make"

# ---------------------------------------------------------------------------
# Setup build directory
# ---------------------------------------------------------------------------
setup:
	@mkdir -p $(BUILD_DIR)/$(DEVICE)
	@mkdir -p $(REPORT_DIR)

# ---------------------------------------------------------------------------
# Smoke test (synthesis only)
# ---------------------------------------------------------------------------
smoke: setup
	@echo "================================================================"
	@echo "  Smoke Test: Synthesis Only"
	@echo "  Device: $(DEVICE) ($(DEVICE_PART))"
	@echo "  Time:   $$(date)"
	@echo "================================================================"
	@mkdir -p $(BUILD_DIR)/smoke_$(DEVICE)
	cd $(BUILD_DIR)/smoke_$(DEVICE) && \
		$(QUARTUS_SH) -t ../../$(TCL_DIR)/create_project.tcl \
			smoke_$(DEVICE) $(DEVICE_PART) $(TOP_MODULE) ../../$(RTL_DIR) && \
		$(QUARTUS_MAP) smoke_$(DEVICE) \
		2>&1 | tee synthesis.log
	@echo ""
	@echo "Smoke test complete. Check $(BUILD_DIR)/smoke_$(DEVICE)/synthesis.log"

# ---------------------------------------------------------------------------
# Full compilation (single device)
# ---------------------------------------------------------------------------
compile: setup
	@echo "================================================================"
	@echo "  Full Compilation"
	@echo "  Device: $(DEVICE) ($(DEVICE_PART))"
	@echo "================================================================"
	@mkdir -p $(BUILD_DIR)/compile_$(DEVICE)
	cd $(BUILD_DIR)/compile_$(DEVICE) && \
		$(QUARTUS_SH) -t ../../$(TCL_DIR)/create_project.tcl \
			compile_$(DEVICE) $(DEVICE_PART) $(TOP_MODULE) ../../$(RTL_DIR) && \
		$(QUARTUS_SH) -t ../../$(TCL_DIR)/compile_design.tcl \
			compile_$(DEVICE) \
		2>&1 | tee compile.log

# ---------------------------------------------------------------------------
# Full compilation (all devices)
# ---------------------------------------------------------------------------
compile-all:
	@echo "Compiling for all devices: $(ALL_DEVICES)"
	@for dev in $(ALL_DEVICES); do \
		echo "--- Building for $$dev ---"; \
		$(MAKE) compile DEVICE=$$dev \
			DEVICE_PART=$$(eval echo \$$PART_$$dev) \
			DEVICE_FAMILY=$$(eval echo \$$FAMILY_$$dev) \
		|| exit 1; \
	done

# ---------------------------------------------------------------------------
# Simulation (all or specific testbench)
# ---------------------------------------------------------------------------
sim: setup
ifdef TB
	@echo "Running simulation: $(TB)"
	@bash $(SCRIPT_DIR)/run_simulation.sh \
		--test $(TB) \
		--workdir $(BUILD_DIR)/sim \
		$(if $(SEED),--seed $(SEED)) \
		$(if $(VERBOSE),--verbose)
else
	@echo "Running all simulations..."
	@bash $(SCRIPT_DIR)/run_simulation.sh \
		--all \
		--workdir $(BUILD_DIR)/sim \
		$(if $(SEED),--seed $(SEED)) \
		$(if $(VERBOSE),--verbose)
endif

# ---------------------------------------------------------------------------
# Full regression
# ---------------------------------------------------------------------------
regress: setup
	@echo "================================================================"
	@echo "  Full Regression"
	@echo "  Suite:  compile + simulation"
	@echo "  Device: $(DEVICE)"
	@echo "  Jobs:   $(JOBS)"
	@echo "  Time:   $$(date)"
	@echo "================================================================"
ifeq ($(DEVICE),all)
	@bash $(SCRIPT_DIR)/run_regression.sh \
		--suite full \
		--device all \
		--jobs $(JOBS) \
		--timeout $(TIMEOUT) \
		--report html
else
	@bash $(SCRIPT_DIR)/run_regression.sh \
		--suite full \
		--device $(DEVICE) \
		--jobs $(JOBS) \
		--timeout $(TIMEOUT) \
		--report html
endif

# ---------------------------------------------------------------------------
# Report generation
# ---------------------------------------------------------------------------
report:
	@echo "Generating regression report..."
	@if [ -f $(BUILD_DIR)/results.csv ]; then \
		$(PYTHON) $(SCRIPT_DIR)/gen_report.py \
			--input $(BUILD_DIR)/results.csv \
			--output $(REPORT_DIR)/regression_report_$(TIMESTAMP).html \
			--format html; \
	else \
		echo "No results.csv found. Run regression first."; \
	fi

# ---------------------------------------------------------------------------
# Trend analysis
# ---------------------------------------------------------------------------
trend:
	@echo "Generating trend analysis..."
	@$(PYTHON) $(SCRIPT_DIR)/trend_analysis.py \
		--data-dir $(REPORT_DIR)/history \
		--output $(REPORT_DIR)/trend_report_$(TIMESTAMP).html

# ---------------------------------------------------------------------------
# Project status
# ---------------------------------------------------------------------------
status:
	@echo "================================================================"
	@echo "  Project Status"
	@echo "================================================================"
	@echo "  RTL sources:    $(words $(RTL_SOURCES)) files"
	@echo "  Testbenches:    $(words $(ALL_TB)) ($(ALL_TB))"
	@echo "  SDC files:      $(words $(SDC_FILES)) files"
	@echo "  Target device:  $(DEVICE) ($(DEVICE_PART))"
	@echo "  Build dir:      $(BUILD_DIR)"
	@echo "================================================================"

# ---------------------------------------------------------------------------
# Clean
# ---------------------------------------------------------------------------
clean:
	@echo "Cleaning build artifacts..."
	rm -rf $(BUILD_DIR)
	rm -rf db incremental_db output_files
	rm -f *.qpf *.qsf *.qws
	rm -f *.rpt *.smsg *.summary
	rm -f $(REPORT_DIR)/*.html $(REPORT_DIR)/*.json
	@echo "Clean complete."
