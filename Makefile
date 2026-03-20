# =============================================================================
# Makefile for Embedded C Tutorial Examples
#
# This Makefile compiles the examples for syntax checking and demonstration.
# For real embedded targets, use your platform's toolchain and linker script.
#
# Usage:
#   make all        — Build all examples (syntax check with gcc)
#   make clean      — Remove build artifacts
#   make example-02 — Build a specific example group
# =============================================================================

# ---- Toolchain (native gcc for syntax checking) ----
CC       = gcc
CFLAGS   = -Wall -Wextra -Wpedantic -std=c11 -fsyntax-only -Wno-unused-function
CFLAGS  += -Wno-unused-variable -Wno-unused-parameter

# For cross-compilation to ARM Cortex-M (uncomment and adjust):
# CC       = arm-none-eabi-gcc
# CFLAGS   = -mcpu=cortex-m4 -mthumb -mfloat-abi=hard -mfpu=fpv4-sp-d16
# CFLAGS  += -Wall -Wextra -Os -std=c11 -ffreestanding -nostdlib
# CFLAGS  += -ffunction-sections -fdata-sections
# LDFLAGS  = -Wl,--gc-sections -T linker_script.ld -nostartfiles

# ---- Source Groups ----
BASICS     = examples/01_basics/data_types.c \
             examples/01_basics/bit_manipulation.c

GPIO       = examples/02_gpio/led_blink.c \
             examples/02_gpio/button_debounce.c

INTERRUPTS = examples/03_interrupts/external_interrupt.c \
             examples/03_interrupts/critical_section.c

TIMERS     = examples/04_timers/systick.c \
             examples/04_timers/pwm.c

UART       = examples/05_uart/uart_polling.c

SPI        = examples/06_spi/spi_master.c

I2C        = examples/07_i2c/i2c_temp_sensor.c

ADC        = examples/08_adc/adc_multichannel.c

RINGBUF    = examples/13_ring_buffer/ring_buffer.c

STATE      = examples/12_state_machine/traffic_light_fsm.c

WATCHDOG   = examples/14_watchdog/iwdg.c

ALL_SOURCES = $(BASICS) $(GPIO) $(INTERRUPTS) $(TIMERS) $(UART) \
              $(SPI) $(I2C) $(ADC) $(RINGBUF) $(STATE) $(WATCHDOG)

# ---- Targets ----
.PHONY: all clean check help

all: check
	@echo ""
	@echo "All examples passed syntax check."

check: $(ALL_SOURCES)
	@echo "Checking syntax for all examples..."
	@for src in $(ALL_SOURCES); do \
		echo "  Checking $$src"; \
		$(CC) $(CFLAGS) $$src 2>&1 || exit 1; \
	done

example-01: $(BASICS)
	@for src in $(BASICS); do $(CC) $(CFLAGS) $$src; done

example-02: $(GPIO)
	@for src in $(GPIO); do $(CC) $(CFLAGS) $$src; done

example-03: $(INTERRUPTS)
	@for src in $(INTERRUPTS); do $(CC) $(CFLAGS) $$src; done

example-04: $(TIMERS)
	@for src in $(TIMERS); do $(CC) $(CFLAGS) $$src; done

example-05: $(UART)
	@for src in $(UART); do $(CC) $(CFLAGS) $$src; done

example-06: $(SPI)
	@for src in $(SPI); do $(CC) $(CFLAGS) $$src; done

example-07: $(I2C)
	@for src in $(I2C); do $(CC) $(CFLAGS) $$src; done

example-08: $(ADC)
	@for src in $(ADC); do $(CC) $(CFLAGS) $$src; done

example-12: $(STATE)
	@for src in $(STATE); do $(CC) $(CFLAGS) $$src; done

example-13: $(RINGBUF)
	@for src in $(RINGBUF); do $(CC) $(CFLAGS) -Iexamples/13_ring_buffer $$src; done

example-14: $(WATCHDOG)
	@for src in $(WATCHDOG); do $(CC) $(CFLAGS) $$src; done

clean:
	@echo "Nothing to clean (syntax-only mode)."

help:
	@echo "Embedded C Tutorial Examples - Build System"
	@echo ""
	@echo "Targets:"
	@echo "  all         Build/check all examples"
	@echo "  check       Syntax-check all source files"
	@echo "  example-NN  Check a specific example group (01-14)"
	@echo "  clean       Remove build artifacts"
	@echo "  help        Show this message"
	@echo ""
	@echo "Examples:"
	@echo "  make all"
	@echo "  make example-02"
	@echo ""
	@echo "For ARM cross-compilation, edit the CC and CFLAGS"
	@echo "variables at the top of this Makefile."
