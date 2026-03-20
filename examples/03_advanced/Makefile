CC      = gcc
CFLAGS  = -Wall -Wextra -std=c11 -pedantic -O2
LDFLAGS = -lm
TARGETS = dma_transfer simple_rtos state_machine low_power ring_buffer

all: $(TARGETS)

%: %.c
	$(CC) $(CFLAGS) -o $@ $< $(LDFLAGS)

clean:
	rm -f $(TARGETS)

.PHONY: all clean
