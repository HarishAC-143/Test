#----------------------------------------------------------------------
# Makefile for Memory Model UVM Verification
#
# Supports multiple simulators via SIMULATOR variable:
#   make run_flop  SIMULATOR=vcs     TEST=mem_write_read_test
#   make run_flop  SIMULATOR=questa  TEST=mem_write_read_test
#   make run_flop  SIMULATOR=xcelium TEST=mem_write_read_test
#----------------------------------------------------------------------

SIMULATOR  ?= vcs
TEST       ?= mem_write_read_test
VERBOSITY  ?= UVM_MEDIUM
SEED       ?= random
TOP_FLOP   ?= tb_top
TOP_LATCH  ?= tb_top_latch

# Source file list
FILELIST    = filelist.f

# Common UVM arguments
UVM_ARGS    = +UVM_TESTNAME=$(TEST) +UVM_VERBOSITY=$(VERBOSITY)

#----------------------------------------------------------------------
# VCS
#----------------------------------------------------------------------
VCS_OPTS    = -full64 -sverilog -ntb_opts uvm-1.2 \
              -timescale=1ns/1ps +vcs+lic+wait \
              -debug_access+all

ifeq ($(SIMULATOR),vcs)
  COMP_CMD  = vcs $(VCS_OPTS) -f $(FILELIST) -top $(TOP) -o simv_$(TOP)
  RUN_CMD   = ./simv_$(TOP) $(UVM_ARGS) +ntb_random_seed=$(SEED)
endif

#----------------------------------------------------------------------
# Questa / ModelSim
#----------------------------------------------------------------------
QUESTA_OPTS = -sv +acc -timescale 1ns/1ps

ifeq ($(SIMULATOR),questa)
  COMP_CMD  = vlog $(QUESTA_OPTS) -f $(FILELIST) && \
              vopt +acc $(TOP) -o opt_$(TOP)
  RUN_CMD   = vsim -c opt_$(TOP) -do "run -all; quit" $(UVM_ARGS) -sv_seed $(SEED)
endif

#----------------------------------------------------------------------
# Xcelium (Cadence)
#----------------------------------------------------------------------
XCEL_OPTS   = -sv -uvm -timescale 1ns/1ps -access +rwc

ifeq ($(SIMULATOR),xcelium)
  COMP_CMD  = xrun $(XCEL_OPTS) -f $(FILELIST) -top $(TOP) \
              $(UVM_ARGS) -svseed $(SEED) -R
  RUN_CMD   = @echo "Xcelium compile-and-run done"
endif

#----------------------------------------------------------------------
# Targets
#----------------------------------------------------------------------

.PHONY: compile_flop compile_latch run_flop run_latch \
        all_tests_flop all_tests_latch clean help

compile_flop:
	$(eval TOP=$(TOP_FLOP))
	$(COMP_CMD)

compile_latch:
	$(eval TOP=$(TOP_LATCH))
	$(COMP_CMD)

run_flop: compile_flop
	$(eval TOP=$(TOP_FLOP))
	$(RUN_CMD)

run_latch: compile_latch
	$(eval TOP=$(TOP_LATCH))
	$(RUN_CMD)

# Run all tests against flop-based memory
all_tests_flop:
	$(MAKE) run_flop TEST=mem_write_read_test
	$(MAKE) run_flop TEST=mem_random_test
	$(MAKE) run_flop TEST=mem_walking_ones_test
	$(MAKE) run_flop TEST=mem_virtual_seq_test
	$(MAKE) run_flop TEST=mem_sequential_vseq_test
	$(MAKE) run_flop TEST=mem_parallel_vseq_test

# Run all tests against latch-based memory
all_tests_latch:
	$(MAKE) run_latch TEST=mem_write_read_test
	$(MAKE) run_latch TEST=mem_random_test
	$(MAKE) run_latch TEST=mem_walking_ones_test
	$(MAKE) run_latch TEST=mem_virtual_seq_test
	$(MAKE) run_latch TEST=mem_sequential_vseq_test
	$(MAKE) run_latch TEST=mem_parallel_vseq_test

clean:
	rm -rf simv* csrc *.vcd *.vpd *.fsdb ucli.key
	rm -rf work transcript vsim.wlf
	rm -rf xcelium.d *.shm *.log *.diag
	rm -rf DVEfiles *.daidir

help:
	@echo "============================================="
	@echo " Memory Model UVM Verification Makefile"
	@echo "============================================="
	@echo ""
	@echo "Usage:"
	@echo "  make run_flop    TEST=<test_name>  - Run test with flop memory"
	@echo "  make run_latch   TEST=<test_name>  - Run test with latch memory"
	@echo "  make all_tests_flop               - Run all tests (flop)"
	@echo "  make all_tests_latch              - Run all tests (latch)"
	@echo "  make clean                         - Clean generated files"
	@echo ""
	@echo "Available tests:"
	@echo "  mem_write_read_test"
	@echo "  mem_random_test"
	@echo "  mem_walking_ones_test"
	@echo "  mem_virtual_seq_test"
	@echo "  mem_sequential_vseq_test"
	@echo "  mem_parallel_vseq_test"
	@echo ""
	@echo "Variables:"
	@echo "  SIMULATOR  = vcs|questa|xcelium  (default: vcs)"
	@echo "  TEST       = <test_name>          (default: mem_write_read_test)"
	@echo "  VERBOSITY  = UVM_NONE|UVM_LOW|UVM_MEDIUM|UVM_HIGH|UVM_FULL"
	@echo "  SEED       = <value>|random       (default: random)"
