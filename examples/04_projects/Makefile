CC      = gcc
CFLAGS  = -Wall -Wextra -std=c11 -pedantic -O2
LDFLAGS = -lm
TARGETS = temperature_monitor led_pattern_controller serial_command_parser debounce_library

all: $(TARGETS)

%: %.c
	$(CC) $(CFLAGS) -o $@ $< $(LDFLAGS)

clean:
	rm -f $(TARGETS)

.PHONY: all clean
