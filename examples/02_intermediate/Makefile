CC      = gcc
CFLAGS  = -Wall -Wextra -std=c11 -pedantic -O2
LDFLAGS = -lm
TARGETS = interrupt_handler timer_config uart_driver adc_reader watchdog_timer

all: $(TARGETS)

%: %.c
	$(CC) $(CFLAGS) -o $@ $< $(LDFLAGS)

clean:
	rm -f $(TARGETS)

.PHONY: all clean
